<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>Sala de Juego - Alumno</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .option-btn {
            background-color: #495057;
            border: 1px solid #6c757d;
            color: white;
            border-radius: 6px;
            padding: 15px;
            margin-bottom: 10px;
            font-size: 1.1rem;
            width: 100%;
            text-align: left;
            transition: background 0.2s;
        }
        .option-btn:hover:not(:disabled) {
            background-color: #ffc107;
            color: #000;
        }
        .option-btn:disabled {
            background-color: #343a40;
            color: #6c757d;
            cursor: not-allowed;
        }
    </style>
</head>
<body class="bg-dark text-white">
    <div class="container mt-4 text-center" id="game-container">
        <h2>Panel de Participante</h2>
        <h4 class="text-info mt-2">Turno actual: <span id="my-turn-display" class="text-warning fw-bold">Esperando...</span></h4>
        <h5 class="text-light">Puntajes generales: <span id="my-scoreboard" class="text-success"></span></h5>

        <!-- Notificación de acciones -->
        <div class="alert alert-primary mt-3 fs-5" id="notification-banner" role="alert">
            Esperando que el profesor seleccione una pregunta...
        </div>

        <!-- Pantalla de Pregunta para el Alumno -->
        <div class="card bg-secondary text-white p-4 mt-3 d-none" id="student-question-box">
            <h3 id="st-category" class="text-warning">Pregunta Activa</h3>
            <h4 class="badge bg-danger fs-5 my-2" id="st-points"></h4>
            <p class="fs-4 my-3" id="st-question"></p>

            <div class="row justify-content-center">
                <div class="col-md-8">
                    <button class="option-btn" id="btn-A" onclick="enviarRespuesta(document.getElementById('txt-A').textContent)">A) <span id="txt-A"></span></button>
                    <button class="option-btn" id="btn-B" onclick="enviarRespuesta(document.getElementById('txt-B').textContent)">B) <span id="txt-B"></span></button>
                    <button class="option-btn" id="btn-C" onclick="enviarRespuesta(document.getElementById('txt-C').textContent)">C) <span id="txt-C"></span></button>
                    <button class="option-btn" id="btn-D" onclick="enviarRespuesta(document.getElementById('txt-D').textContent)">D) <span id="txt-D"></span></button>
                </div>
            </div>
        </div>

        <!-- Pantalla de espera por turnos -->
        <div class="card bg-secondary text-white p-4 mt-3" id="waiting-turn-box">
            <h3>Estado del Juego</h3>
            <p class="fs-5 text-warning mt-2" id="waiting-msg">Si es tu turno, podrás responder cuando el profesor abra una pregunta.</p>
        </div>
    </div>

    <!-- Dashboard Final / Podio para Estudiantes -->
    <div class="container mt-5 p-5 bg-secondary rounded text-center d-none" id="student-dashboard-panel">
        <h1 class="text-warning fw-bold">🏆 ¡Juego Finalizado! 🏆</h1>
        <hr class="border-light my-4">
        <h3 class="text-light">El Gran Ganador es:</h3>
        <h1 class="text-success fw-bold display-3 my-3" id="st-dash-winner"></h1>
        <h4 class="text-info mb-4">Puntaje Máximo: <span id="st-dash-max-score"></span> Puntos</h4>
        
        <h4 class="text-light mt-4">Tabla General de Posiciones:</h4>
        <ul class="list-group col-md-8 mx-auto text-dark fs-5 mt-3" id="st-dash-scores-list"></ul>
        
        <button class="btn btn-primary btn-lg mt-5 px-5" onclick="localStorage.removeItem('nombreJugador'); window.location.href='index.jsp';">Salir al Inicio</button>
    </div>

    <script>
        let ws;
        let myTeamName = localStorage.getItem("nombreJugador") || "Jugador";
        let currentTurnPlayer = "";
        let isMyTurn = false;
        
        let loc = window.location;
        let wsPath = "ws://" + loc.host + "${pageContext.request.contextPath}/juegoSocket";
        ws = new WebSocket(wsPath);

        ws.onopen = function() {
            ws.send("JOIN_INDIVIDUAL:" + myTeamName);
        };

        ws.onmessage = function(event) {
            let msg = event.data;
            if (msg.startsWith("STATE_UPDATE:")) {
                let data = msg.substring(13);
                let parts = data.split(";");
                currentTurnPlayer = parts[0].replace("TURNO:", "").trim();
                let scorePart = parts[1].replace("SCORES:", "");

                document.getElementById('my-turn-display').textContent = currentTurnPlayer;
                document.getElementById('my-scoreboard').textContent = scorePart;

                isMyTurn = (currentTurnPlayer.toLowerCase() === myTeamName.toLowerCase());
                let buttons = document.querySelectorAll('.option-btn');

                if (isMyTurn) {
                    document.getElementById('waiting-msg').textContent = "¡Es TU turno de responder!";
                    document.getElementById('waiting-msg').className = "fs-5 text-success fw-bold mt-2";
                    buttons.forEach(b => b.removeAttribute('disabled'));
                } else {
                    document.getElementById('waiting-msg').textContent = "Esperando turno... Le toca a: " + currentTurnPlayer;
                    document.getElementById('waiting-msg').className = "fs-5 text-warning mt-2";
                    buttons.forEach(b => b.setAttribute('disabled', 'true'));
                    document.getElementById('student-question-box').classList.add('d-none');
                }
            } else if (msg.startsWith("NOTIFICATION:")) {
                let text = msg.substring(13);
                let banner = document.getElementById('notification-banner');
                banner.textContent = text;
                banner.className = "alert alert-warning mt-3 fs-5";
                document.getElementById('student-question-box').classList.add('d-none');
            } else if (msg.startsWith("ACTIVE_QUESTION:")) {
                let rawData = msg.substring(16);
                let pParts = rawData.split("|||");
                
                document.getElementById('st-points').textContent = pParts[0] + " Puntos";
                document.getElementById('st-question').textContent = pParts[2];
                document.getElementById('txt-A').textContent = pParts[3];
                document.getElementById('txt-B').textContent = pParts[4];
                document.getElementById('txt-C').textContent = pParts[5];
                document.getElementById('txt-D').textContent = pParts[6];

                document.getElementById('student-question-box').classList.remove('d-none');

                let buttons = document.querySelectorAll('.option-btn');
                if (isMyTurn) {
                    buttons.forEach(b => b.removeAttribute('disabled'));
                } else {
                    buttons.forEach(b => b.setAttribute('disabled', 'true'));
                }
            } else if (msg === "CLOSE_QUESTION") {
                document.getElementById('student-question-box').classList.add('d-none');
            } else if (msg === "GAME_RESET") {
                alert("El profesor ha reiniciado la partida.");
                localStorage.removeItem("nombreJugador");
                window.location.href = "index.jsp";
            } else if (msg.startsWith("GAME_FINISHED:")) {
                let parts = msg.split(":");
                let winner = parts[1];
                let maxScore = parts[2];
                let rawScores = parts[3] ? parts[3] : "";
                let rawTeams = parts[4] ? parts[4] : "";

                // Ocultar paneles de juego
                if (document.getElementById('main-board-wrapper')) document.getElementById('main-board-wrapper').classList.add('d-none');
                if (document.getElementById('question-panel')) document.getElementById('question-panel').classList.add('d-none');
                if (document.getElementById('game-container')) document.getElementById('game-container').classList.add('d-none');
                if (document.getElementById('student-question-box')) document.getElementById('student-question-box').classList.add('d-none');

                // Mapear integrantes solo si existen
                let teamMembersObj = {};
                let isGroupMode = false;
                if (rawTeams && rawTeams.length > 0) {
                    rawTeams.split("|").forEach(tInfo => {
                        let match = tInfo.match(/(.*)\[(.*)\]/);
                        if (match) {
                            let team = match[1].trim();
                            let members = match[2].trim();
                            teamMembersObj[team] = members;
                            if (members && members !== team) {
                                isGroupMode = true;
                            }
                        }
                    });
                }

                // Mostrar ganador y sus integrantes (si es grupal)
                let dashWinnerEl = document.getElementById('dash-winner') || document.getElementById('st-dash-winner');
                let dashMaxScoreEl = document.getElementById('dash-max-score') || document.getElementById('st-dash-max-score');
                
                if (dashWinnerEl) {
                    if (isGroupMode && teamMembersObj[winner]) {
                        dashWinnerEl.innerHTML = `${winner} <br><span class="fs-4 text-light">Integrantes: ${teamMembersObj[winner]}</span>`;
                    } else {
                        dashWinnerEl.textContent = winner;
                    }
                }
                if (dashMaxScoreEl) {
                    dashMaxScoreEl.textContent = maxScore;
                }

                // Poblar la tabla general de posiciones de forma segura
                let list = document.getElementById('dash-scores-list') || document.getElementById('st-dash-scores-list');
                if (list) {
                    list.innerHTML = "";
                    if (rawScores.length > 0) {
                        rawScores.split(",").forEach(item => {
                            if (!item) return;
                            let equalIndex = item.lastIndexOf("=");
                            if (equalIndex === -1) return;
                            
                            let teamName = item.substring(0, equalIndex);
                            let teamScore = item.substring(equalIndex + 1);
                            let membersStr = (isGroupMode && teamMembersObj[teamName]) ? `Integrantes: ${teamMembersObj[teamName]}` : "";

                            let li = document.createElement('li');
                            li.className = "list-group-item d-flex justify-content-between align-items-center fw-bold py-3";
                            
                            if (membersStr) {
                                li.innerHTML = `<div class="text-start"><span>👤 ${teamName}</span><br><small class="text-muted fw-normal">${membersStr}</small></div> <span class="badge bg-success fs-5">${teamScore} pts</span>`;
                            } else {
                                li.innerHTML = `<div class="text-start"><span>👤 ${teamName}</span></div> <span class="badge bg-success fs-5">${teamScore} pts</span>`;
                            }
                            list.appendChild(li);
                        });
                    }
                }

                // Mostrar panel de dashboard final
                let dashPanel = document.getElementById('dashboard-panel') || document.getElementById('student-dashboard-panel');
                if (dashPanel) dashPanel.classList.remove('d-none');
            }
        };

        function enviarRespuesta(optionText) {
            if (!isMyTurn) {
                alert("No es tu turno de responder. Turno actual: " + currentTurnPlayer);
                return;
            }
            ws.send("SUBMIT_ANSWER:" + myTeamName + ":" + optionText);
            document.getElementById('student-question-box').classList.add('d-none');
        }
    </script>
</body>
</html>