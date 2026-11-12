<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>Tablero - Jeopardy TICs</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .jeopardy-cell {
            height: 50px;
            font-weight: bold;
            font-size: 1rem;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 6px;
            border-radius: 4px;
            background-color: #0dcaf0;
            color: #000;
        }
        .jeopardy-cell:hover:not(.disabled-cell) {
            background-color: #ffc107 !important;
        }
        .disabled-cell {
            background-color: #343a40 !important;
            color: #6c757d !important;
            cursor: not-allowed;
            pointer-events: none;
        }
        .option-box {
            background-color: #495057;
            border: 1px solid #6c757d;
            border-radius: 6px;
            padding: 10px 15px;
            margin-bottom: 8px;
            text-align: left;
            font-size: 1.1rem;
        }
    </style>
</head>
<body class="bg-dark text-white">
    <div class="container mt-3 text-center" id="main-board-wrapper">
        <h1>Jeopardy TICs - Universidad de Guayaquil</h1>
        <div class="row mt-2">
            <div class="col-md-6">
                <h4 class="text-info">Turno del equipo: <span id="current-turn" class="text-warning fw-bold">Cargando...</span></h4>
            </div>
            <div class="col-md-6">
                <h5 class="text-light">Puntajes: <span id="scoreboard" class="text-success">Sin puntajes</span></h5>
            </div>
        </div>
        
        <div class="alert alert-secondary mt-2 py-1" id="host-notification">Esperando selección de pregunta...</div>
        
        <!-- Tablero de 5 columnas -->
        <div class="row mt-3 px-2" id="board-container"></div>
    </div>

    <!-- Panel de Pregunta Activa (Host) -->
    <div class="container mt-4 p-4 bg-secondary rounded d-none" id="question-panel">
        <h3 id="panel-category" class="text-warning"></h3>
        <h2 id="panel-points" class="badge bg-danger fs-4 my-2"></h2>
        <p id="panel-question" class="fs-4 my-3"></p>
        
        <div class="row justify-content-center">
            <div class="col-md-8">
                <div class="option-box">A) <span id="text-A"></span></div>
                <div class="option-box">B) <span id="text-B"></span></div>
                <div class="option-box">C) <span id="text-C"></span></div>
                <div class="option-box">D) <span id="text-D"></span></div>
            </div>
        </div>

        <div id="panel-answer-box" class="d-none mb-3 mt-3">
            <hr class="border-light">
            <h4 class="text-success">Respuesta Correcta:</h4>
            <p id="panel-answer" class="fs-4 text-info fw-bold"></p>
        </div>
        
        <div class="mt-4">
            <button class="btn btn-warning btn-lg me-2 mb-2" onclick="revelarRespuesta()">Ver Respuesta</button>
            <button class="btn btn-danger btn-lg me-2 mb-2" onclick="pasarTurno()">Forzar Salto de Turno</button>
            <button class="btn btn-light btn-lg me-2 mb-2" onclick="cerrarPanelPregunta()">Volver al Tablero</button>
            <button class="btn btn-outline-warning btn-lg me-2 mb-2" onclick="reiniciarPartida()">Reiniciar Juego</button>
            <button class="btn btn-success btn-lg mb-2" onclick="finalizarJuego()">Finalizar y Ver Ganador</button>
        </div>
    </div>

    <!-- Dashboard Final / Podio (Host) -->
    <div class="container mt-5 p-5 bg-secondary rounded text-center d-none" id="dashboard-panel">
        <h1 class="text-warning fw-bold">🏆 ¡Juego Finalizado! 🏆</h1>
        <hr class="border-light my-4">
        <h3 class="text-light">El Gran Ganador es:</h3>
        <h1 class="text-success fw-bold display-3 my-3" id="dash-winner"></h1>
        <h4 class="text-info mb-4">Puntaje Máximo: <span id="dash-max-score"></span> Puntos</h4>
        
        <h4 class="text-light mt-4">Tabla General de Posiciones:</h4>
        <ul class="list-group col-md-6 mx-auto text-dark fs-5 mt-3" id="dash-scores-list"></ul>
        
        <button class="btn btn-primary btn-lg mt-5 px-5" onclick="location.href='index.jsp'">Volver al Inicio</button>
    </div>

    <script>
        let ws;
        let activePoints = 0;
        let activeCell = null;
        let activeTurnPlayer = "";

        const categories = [
            {
                name: "Servidores Web",
                questions: Array.from({length: 10}, (_, i) => ({
                    points: (i + 1) * 100,
                    question: `¿Cuál es una característica clave de JBoss, GlassFish o Tomcat en el nivel ${(i + 1) * 100}?`,
                    options: [
                        "Son contenedores web y de servlets de código abierto",
                        "Solo funcionan con aplicaciones en C++",
                        "Requieren obligatoriamente un sistema operativo mainframe",
                        "No soportan tecnología Servlet ni JSP"
                    ],
                    answer: "Son contenedores web y de servlets de código abierto"
                }))
            },
            {
                name: "Frameworks Java",
                questions: Array.from({length: 10}, (_, i) => ({
                    points: (i + 1) * 100,
                    question: `Concepto esencial sobre Spring, Maven o Hibernate (Nivel ${(i + 1) * 100})`,
                    options: [
                        "Maven se usa para gestión de dependencias y ciclo de vida del proyecto",
                        "Hibernate es un servidor de correo electrónico",
                        "Spring solo compila archivos HTML estáticos",
                        "Ninguno pertenece al ecosistema Java"
                    ],
                    answer: "Maven se usa para gestión de dependencias y ciclo de vida del proyecto"
                }))
            },
            {
                name: "Java Web Start",
                questions: Array.from({length: 10}, (_, i) => ({
                    points: (i + 1) * 100,
                    question: `Arquitectura de Java Web Start (JWS) en el nivel ${(i + 1) * 100}:`,
                    options: [
                        "Permite ejecutar aplicaciones Java directamente desde un navegador usando un archivo JNLP",
                        "Es una base de datos relacional para servidores web",
                        "Reemplaza por completo al protocolo TCP/IP",
                        "Es un entorno operativo exclusivo para smartphones"
                    ],
                    answer: "Permite ejecutar aplicaciones Java directamente desde un navegador usando un archivo JNLP"
                }))
            },
            {
                name: "JSP & Servlets",
                questions: Array.from({length: 10}, (_, i) => ({
                    points: (i + 1) * 100,
                    question: `Sobre el ciclo de vida o arquitectura de JSP y Servlets (Nivel ${(i + 1) * 100}):`,
                    options: [
                        "Los Servlets manejan la lógica del controlador y las JSP se enfocan en la vista HTML",
                        "Las JSP no pueden contener código Java embebido",
                        "Los Servlets se ejecutan exclusivamente en el navegador cliente",
                        "No tienen relación con el servidor GlassFish"
                    ],
                    answer: "Los Servlets manejan la lógica del controlador y las JSP se enfocan en la vista HTML"
                }))
            },
            {
                name: "Cliente / Servidor",
                questions: Array.from({length: 10}, (_, i) => ({
                    points: (i + 1) * 100,
                    question: `En aplicaciones cliente/servidor con JSP y Servlets (Nivel ${(i + 1) * 100}):`,
                    options: [
                        "El cliente realiza peticiones HTTP y el servidor GlassFish procesa la respuesta",
                        "El servidor web actúa únicamente como base de datos local",
                        "No se requiere red ni protocolos web para comunicarse",
                        "El navegador web procesa directamente el código fuente Java del servidor"
                    ],
                    answer: "El cliente realiza peticiones HTTP y el servidor GlassFish procesa la respuesta"
                }))
            }
        ];

        window.onload = function() {
            renderBoard();
            conectarWebSocket();
        };

        function renderBoard() {
            let container = document.getElementById('board-container');
            container.innerHTML = "";

            categories.forEach((cat, catIndex) => {
                let col = document.createElement('div');
                col.className = "col";
                
                let header = document.createElement('div');
                header.className = "card bg-primary text-white mb-2 text-center";
                header.innerHTML = `<div class="card-body p-2" style="font-size:0.8rem; min-height:45px;"><b>${cat.name}</b></div>`;
                col.appendChild(header);
                
                cat.questions.forEach((q, qIndex) => {
                    let cell = document.createElement('div');
                    cell.className = "jeopardy-cell";
                    cell.textContent = q.points;
                    
                    cell.addEventListener('click', function() {
                        abrirPregunta(catIndex, qIndex, cell);
                    });
                    
                    col.appendChild(cell);
                });
                
                container.appendChild(col);
            });
        }

        function conectarWebSocket() {
            let loc = window.location;
            let wsPath = "ws://" + loc.host + "${pageContext.request.contextPath}/juegoSocket";
            ws = new WebSocket(wsPath);

            ws.onmessage = function(event) {
                let msg = event.data;
                if (msg.startsWith("STATE_UPDATE:")) {
                    let data = msg.substring(13);
                    let parts = data.split(";");
                    let turnPart = parts[0] ? parts[0].replace("TURNO:", "") : "Esperando...";
                    let scorePart = parts[1] ? parts[1].replace("SCORES:", "") : "";

                    activeTurnPlayer = turnPart;
                    document.getElementById('current-turn').textContent = activeTurnPlayer;
                    document.getElementById('scoreboard').textContent = scorePart ? scorePart : "Sin puntajes aún";
                } else if (msg.startsWith("NOTIFICATION:")) {
                    document.getElementById('host-notification').textContent = msg.substring(13);
                } else if (msg === "CLOSE_QUESTION") {
                    cerrarPanelPregunta();
                } else if (msg === "GAME_RESET") {
                    alert("La partida ha sido reiniciada.");
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
        }

        function abrirPregunta(catIndex, qIndex, cellElement) {
            let qData = categories[catIndex].questions[qIndex];
            activePoints = qData.points;
            activeCell = cellElement;
            
            document.getElementById('panel-category').textContent = categories[catIndex].name;
            document.getElementById('panel-points').textContent = activePoints + " Puntos";
            document.getElementById('panel-question').textContent = qData.question;
            
            document.getElementById('text-A').textContent = qData.options[0];
            document.getElementById('text-B').textContent = qData.options[1];
            document.getElementById('text-C').textContent = qData.options[2];
            document.getElementById('text-D').textContent = qData.options[3];
            
            document.getElementById('panel-answer').textContent = qData.answer;
            document.getElementById('panel-answer-box').classList.add('d-none');
            
            document.getElementById('main-board-wrapper').classList.add('d-none');
            document.getElementById('question-panel').classList.remove('d-none');

            ws.send("ACTIVE_QUESTION:" + activePoints + "|||" + qData.answer + "|||" + qData.question + "|||" + qData.options[0] + "|||" + qData.options[1] + "|||" + qData.options[2] + "|||" + qData.options[3]);
        }

        function revelarRespuesta() {
            document.getElementById('panel-answer-box').classList.remove('d-none');
        }

        function pasarTurno() {
            ws.send("SKIP_TURN");
            finalizarPregunta();
        }

        function cerrarPanelPregunta() {
            finalizarPregunta();
        }

        function finalizarPregunta() {
            if (activeCell) {
                activeCell.classList.add('disabled-cell');
            }
            document.getElementById('question-panel').classList.add('d-none');
            document.getElementById('main-board-wrapper').classList.remove('d-none');
        }

        function reiniciarPartida() {
            if (confirm("¿Estás seguro de que deseas reiniciar la partida actual?")) {
                ws.send("RESET_GAME");
            }
        }

        function finalizarJuego() {
            if (confirm("¿Estás seguro de finalizar el juego y mostrar el podio de ganadores?")) {
                ws.send("FINISH_GAME");
            }
        }
    </script>
</body>
</html>