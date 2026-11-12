package com.jeopardy.websocket;

import java.util.Map;
import java.util.List;
import java.util.ArrayList;
import jakarta.websocket.OnClose;
import jakarta.websocket.OnMessage;
import jakarta.websocket.OnOpen;
import jakarta.websocket.Session;
import jakarta.websocket.server.ServerEndpoint;
import java.io.IOException;
import java.util.*;

@ServerEndpoint("/juegoSocket")
public class GameServer {
    private static final Set<Session> sessions = Collections.synchronizedSet(new HashSet<>());
    private static final Map<String, List<String>> teamMembersMap = Collections.synchronizedMap(new LinkedHashMap<>());
    private static final Map<String, Integer> scores = Collections.synchronizedMap(new LinkedHashMap<>());
    private static String gameMode = "individual";
    private static int maxMembersPerTeam = 4;
    private static boolean gameStarted = false;
    private static int currentTurnIndex = 0;
    
    private static String lastActiveQuestionMsg = "";
    private static String activeCorrectAnswer = "";
    private static int activeQuestionPoints = 0;

    private static final String ADMIN_PASSWORD = "admin";

    @OnOpen
    public void onOpen(Session session) {
        sessions.add(session);
        try {
            session.getBasicRemote().sendText("CONFIG_UPDATE:" + gameMode + ":" + maxMembersPerTeam);
            if (gameStarted) {
                session.getBasicRemote().sendText("GAME_STARTED:" + gameMode);
            }
            sendStateToSession(session);
            
            // Si hay una pregunta activa en curso, enviársela al nuevo cliente
            if (!lastActiveQuestionMsg.isEmpty()) {
                session.getBasicRemote().sendText(lastActiveQuestionMsg);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @OnMessage
    public void onMessage(String message, Session session) throws IOException {
        if (message.startsWith("LOGIN_ADMIN:")) {
            String pass = message.substring(12);
            if (pass.equals(ADMIN_PASSWORD)) {
                session.getBasicRemote().sendText("LOGIN_SUCCESS");
            } else {
                session.getBasicRemote().sendText("LOGIN_ERROR:Contraseña incorrecta");
            }
        } else if (message.startsWith("CONFIG:")) {
            String[] parts = message.split(":");
            gameMode = parts[1];
            if (parts.length > 2) {
                maxMembersPerTeam = Integer.parseInt(parts[2]);
            }
            broadcast("CONFIG_UPDATE:" + gameMode + ":" + maxMembersPerTeam);
        } else if (message.startsWith("JOIN_TEAM:") || message.startsWith("JOIN_INDIVIDUAL:")) {
            String[] parts = message.split(":", 3);
            String name = parts[1].trim();
            
            List<String> members;
            if (parts.length > 2) {
                members = Arrays.asList(parts[2].split(","));
            } else {
                members = Collections.singletonList(name);
            }

            teamMembersMap.put(name, members);
            scores.putIfAbsent(name, 0);
            session.getUserProperties().put("teamName", name);
            broadcastState();
        } else if (message.equals("START_GAME")) {
            gameStarted = true;
            broadcast("GAME_STARTED:" + gameMode);
            broadcastState();
        } else if (message.startsWith("ACTIVE_QUESTION:")) {
            lastActiveQuestionMsg = message;
            
            // Extraer la respuesta correcta para la validación interna del servidor
            String[] subParts = message.substring(16).split("\\|\\|\\|");
            if (subParts.length > 1) {
                activeQuestionPoints = Integer.parseInt(subParts[0]);
                activeCorrectAnswer = subParts[1];
            }
            
            // Reenviar el mensaje completo intacto a todos los estudiantes
            broadcast(message);
        } else if (message.equals("RESET_GAME")) {
            gameStarted = false;
            currentTurnIndex = 0;
            activeCorrectAnswer = "";
            activeQuestionPoints = 0;
            lastActiveQuestionMsg = "";
            scores.clear();
            teamMembersMap.clear();
            
            broadcast("GAME_RESET");
            broadcastState();
        } else if (message.equals("FINISH_GAME")) {
            gameStarted = false;
            lastActiveQuestionMsg = "";
            
            if (scores.isEmpty()) {
                scores.put("Sin participantes", 0);
            }

            // Encontrar al ganador con mayor puntaje
            String winner = "Nadie";
            int maxScore = -1;
            for (Map.Entry<String, Integer> entry : scores.entrySet()) {
                if (entry.getValue() > maxScore) {
                    maxScore = entry.getValue();
                    winner = entry.getKey();
                }
            }
            
            // Construir el reporte de puntajes ordenados de mayor a menor
            List<String> keysList = new ArrayList<>(scores.keySet());
            keysList.sort((a, b) -> scores.get(b).compareTo(scores.get(a)));

            List<String> finalScores = new ArrayList<>();
            for (String key : keysList) {
                finalScores.add(key + "=" + scores.get(key));
            }
            
            // Construir el reporte de los integrantes de cada equipo
            List<String> teamDetails = new ArrayList<>();
            for (Map.Entry<String, List<String>> entry : teamMembersMap.entrySet()) {
                teamDetails.add(entry.getKey() + "[" + String.join(", ", entry.getValue()) + "]");
            }
            
            String dashboardData = "GAME_FINISHED:" + winner + ":" + maxScore + ":" + String.join(",", finalScores) + ":" + String.join("|", teamDetails);
            broadcast(dashboardData);

            // Limpiar datos para que la sala de espera inicie completamente limpia la próxima vez
            scores.clear();
            teamMembersMap.clear();
            currentTurnIndex = 0;
        } else if (message.startsWith("SUBMIT_ANSWER:")) {
            String[] parts = message.split(":", 3);
            String team = parts[1].trim();
            String chosenAnswer = parts[2].trim();

            List<String> keys = new ArrayList<>(teamMembersMap.keySet());
            String currentTurnTeam = keys.isEmpty() ? "" : keys.get(currentTurnIndex);

            if (!team.equalsIgnoreCase(currentTurnTeam.trim())) {
                session.getBasicRemote().sendText("NOTIFICATION:No es tu turno. Le toca a: " + currentTurnTeam);
                return; 
            }

            // 1. CERRAR LA PREGUNTA INMEDIATAMENTE PARA TODOS
            lastActiveQuestionMsg = "";
            broadcast("CLOSE_QUESTION");

            // 2. Validar respuesta y otorgar puntos si acierta
            if (chosenAnswer.equalsIgnoreCase(activeCorrectAnswer.trim())) {
                scores.put(currentTurnTeam, scores.getOrDefault(currentTurnTeam, 0) + activeQuestionPoints);
                broadcast("NOTIFICATION:¡El equipo " + currentTurnTeam + " respondió CORRECTAMENTE y ganó " + activeQuestionPoints + " puntos!");
            } else {
                broadcast("NOTIFICATION:El equipo " + currentTurnTeam + " falló. La respuesta correcta era: " + activeCorrectAnswer);
            }

            // 3. Rotar al siguiente turno
            if (!keys.isEmpty()) {
                currentTurnIndex = (currentTurnIndex + 1) % keys.size();
            }
            broadcastState();

        } else if (message.equals("SKIP_TURN")) {
            List<String> keys = new ArrayList<>(teamMembersMap.keySet());
            String skippedTeam = keys.isEmpty() ? "" : keys.get(currentTurnIndex);
            
            // Cerrar la pregunta de inmediato
            lastActiveQuestionMsg = "";
            broadcast("CLOSE_QUESTION");
            broadcast("NOTIFICATION:El equipo " + skippedTeam + " pasó el turno.");

            if (!keys.isEmpty()) {
                currentTurnIndex = (currentTurnIndex + 1) % keys.size();
            }
            broadcastState();
        }
    }

    @OnClose
    public void onClose(Session session) {
        sessions.remove(session);
        String teamName = (String) session.getUserProperties().get("teamName");
        if (teamName != null) {
            teamMembersMap.remove(teamName);
            scores.remove(teamName);
            broadcastState();
        }
    }

    private void sendStateToSession(Session session) {
        try {
            List<String> keys = new ArrayList<>(teamMembersMap.keySet());
            String currentTurn = keys.isEmpty() ? "Esperando participantes..." : keys.get(currentTurnIndex);
            
            StringBuilder sb = new StringBuilder("STATE_UPDATE:");
            sb.append("TURNO:").append(currentTurn).append(";");
            sb.append("SCORES:");
            
            List<String> scoreInfo = new ArrayList<>();
            for (String t : keys) {
                scoreInfo.add(t + "=" + scores.get(t));
            }
            sb.append(String.join(",", scoreInfo));
            sb.append(";TEAMS:");
            
            List<String> teamDetails = new ArrayList<>();
            for (Map.Entry<String, List<String>> entry : teamMembersMap.entrySet()) {
                teamDetails.add(entry.getKey() + "[" + String.join(", ", entry.getValue()) + "]");
            }
            sb.append(String.join("|", teamDetails));

            session.getBasicRemote().sendText(sb.toString());
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void broadcastState() {
        synchronized (sessions) {
            for (Session s : sessions) {
                sendStateToSession(s);
            }
        }
    }

    private void broadcast(String message) {
        synchronized (sessions) {
            for (Session s : sessions) {
                try {
                    s.getBasicRemote().sendText(message);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }
}