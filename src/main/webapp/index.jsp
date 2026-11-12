<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>Jeopardy TICs - Sala de Espera</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-white">
    <div class="container mt-5">
        <div class="text-center mb-4">
            <h1>Jeopardy TICs - Universidad de Guayaquil</h1>
        </div>

        <!-- SECCIÓN 1: Selección de Rol -->
        <div class="row justify-content-center" id="role-selection">
            <div class="col-md-5 text-center">
                <div class="card bg-secondary text-white p-4 shadow">
                    <h3>¿Cómo deseas ingresar?</h3>
                    <button class="btn btn-warning btn-lg mt-3 w-100" onclick="pedirPasswordHost()">Soy el Profesor (Host)</button>
                    <button class="btn btn-primary btn-lg mt-3 w-100" onclick="iniciarComoAlumno()">Soy Alumno (Participante)</button>
                </div>
            </div>
        </div>

        <!-- SECCIÓN 2: Panel de Contraseña Host -->
        <div class="row justify-content-center d-none" id="password-panel">
            <div class="col-md-4">
                <div class="card bg-secondary text-white p-4 text-center">
                    <h3>Seguridad del Host</h3>
                    <p class="text-muted">Ingresa la contraseña de profesor</p>
                    <input type="password" id="admin-pass-input" class="form-control my-3" placeholder="Contraseña">
                    <button class="btn btn-warning w-100 mb-2" onclick="verificarPassword()">Ingresar</button>
                    <button class="btn btn-outline-light btn-sm" onclick="location.reload()">Volver</button>
                </div>
            </div>
        </div>

        <!-- SECCIÓN 3: Panel del Host (Configuración) -->
        <div class="row justify-content-center d-none" id="host-panel">
            <div class="col-md-7">
                <div class="card bg-secondary text-white p-4">
                    <h3>Panel de Control del Host</h3>
                    <div class="row mt-3">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Modo de juego:</label>
                            <select id="game-mode-select" class="form-select" onchange="toggleHostOptions()">
                                <option value="individual">Modo Individual</option>
                                <option value="grupos">Modo por Grupos / Equipos</option>
                            </select>
                        </div>
                        <div class="col-md-6 mb-3 d-none" id="max-members-container">
                            <label class="form-label">Máx. integrantes por equipo:</label>
                            <input type="number" id="max-members-input" class="form-control" value="4" min="1" max="10">
                        </div>
                    </div>
                    <button class="btn btn-info w-100 mb-3" onclick="configurarPartida()">Aplicar Configuración</button>
                    
                    <hr>
                    <h5>Participantes / Equipos Conectados:</h5>
                    <ul id="host-participants-list" class="list-group text-dark mb-3"></ul>
                    
                    <button class="btn btn-success btn-lg w-100" onclick="iniciarJuegoHost()">&iexcl;Comenzar Partida!</button>
                </div>
            </div>
        </div>

        <!-- SECCIÓN 4: Panel del Alumno -->
        <div class="row justify-content-center d-none" id="player-panel">
            <div class="col-md-6">
                <div class="card bg-secondary text-white p-4" id="player-login-box">
                    <h3 class="text-center mb-3">Unirse a la Sala</h3>
                    <p class="text-center text-warning" id="lbl-modo-aviso">Modo: Cargando...</p>
                    
                    <div id="form-individual" class="d-none">
                        <label class="form-label">Tu Nombre:</label>
                        <input type="text" id="player-name" class="form-control mb-3" placeholder="Ej. Jahir Navas">
                    </div>

                    <div id="form-grupos" class="d-none">
                        <label class="form-label">Nombre del Equipo:</label>
                        <input type="text" id="team-name" class="form-control mb-3" placeholder="Ej. Los TICs Masters">
                        
                        <label class="form-label">Integrantes del Equipo (Máx. <span id="max-allowed-label">4</span>):</label>
                        <div id="members-inputs-container" class="mb-3"></div>
                        <button class="btn btn-sm btn-outline-light mb-3" onclick="agregarCampoIntegrante()">+ Agregar Integrante</button>
                    </div>

                    <button class="btn btn-success w-100 btn-lg" onclick="unirseSala()">Entrar al Lobby</button>
                </div>

                <div class="card bg-secondary text-white p-4 d-none text-center" id="player-waiting-box">
                    <h3>¡Registrado con éxito!</h3>
                    <p class="text-warning mt-2">Esperando a que el profesor inicie el juego...</p>
                    <hr>
                    <h5>Participantes en la sala:</h5>
                    <ul id="player-participants-list" class="list-group text-dark mt-3"></ul>
                </div>
            </div>
        </div>
    </div>

    <script>
        let ws;
        let currentMode = "individual";
        let maxMembers = 4;

        // Iniciar la conexión WebSocket al cargar la página en segundo plano
        window.onload = function() {
            conectarWS();
        };

        function conectarWS() {
            if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
                return;
            }
            let loc = window.location;
            let wsPath = "ws://" + loc.host + "${pageContext.request.contextPath}/juegoSocket";
            ws = new WebSocket(wsPath);

            ws.onopen = function() {
                console.log("WebSocket conectado correctamente.");
            };

            ws.onerror = function(err) {
                console.error("Error en WebSocket:", err);
            };

            ws.onmessage = function(event) {
                let msg = event.data;
                if (msg === "LOGIN_SUCCESS") {
                    document.getElementById('password-panel').classList.add('d-none');
                    document.getElementById('host-panel').classList.remove('d-none');
                } else if (msg.startsWith("LOGIN_ERROR:")) {
                    alert(msg.substring(12));
                } else if (msg.startsWith("CONFIG_UPDATE:")) {
                    let parts = msg.split(":");
                    currentMode = parts[1];
                    maxMembers = parseInt(parts[2]);
                    actualizarInterfazModo();
                } else if (msg.startsWith("STATE_UPDATE:")) {
                    parseStateUpdate(msg);
                } else if (msg.startsWith("ERROR:")) {
                    alert(msg.substring(6));
                } else if (msg.startsWith("GAME_STARTED:")) {
                    let mode = msg.split(":")[1];
                    alert("¡El juego ha comenzado!");
                    
                    let hostPanel = document.getElementById('host-panel');
                    if (hostPanel && !hostPanel.classList.contains('d-none')) {
                        window.location.href = "tablero.jsp?mode=" + mode;
                    } else {
                        window.location.href = "estudiante.jsp";
                    }
                }
            };
        }

        function pedirPasswordHost() {
            document.getElementById('role-selection').classList.add('d-none');
            document.getElementById('password-panel').classList.remove('d-none');
        }

        function verificarPassword() {
            let pass = document.getElementById('admin-pass-input').value;
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send("LOGIN_ADMIN:" + pass);
            } else {
                alert("La conexión con el servidor no está lista. Inténtalo de nuevo en un segundo.");
                conectarWS();
            }
        }

        function iniciarComoAlumno() {
            document.getElementById('role-selection').classList.add('d-none');
            document.getElementById('player-panel').classList.remove('d-none');
            actualizarInterfazModo();
        }

        function toggleHostOptions() {
            let mode = document.getElementById('game-mode-select').value;
            let maxContainer = document.getElementById('max-members-container');
            if (mode === "grupos") {
                maxContainer.classList.remove('d-none');
            } else {
                maxContainer.classList.add('d-none');
            }
        }

        function configurarPartida() {
            let mode = document.getElementById('game-mode-select').value;
            let max = document.getElementById('max-members-input').value;
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send("CONFIG:" + mode + ":" + max);
                alert("Configuración aplicada.");
            } else {
                alert("No hay conexión activa con el servidor.");
            }
        }

        function actualizarInterfazModo() {
            let lblAviso = document.getElementById('lbl-modo-aviso');
            let formInd = document.getElementById('form-individual');
            let formGrp = document.getElementById('form-grupos');
            let maxLbl = document.getElementById('max-allowed-label');

            if (lblAviso) lblAviso.textContent = "Modo de juego: " + currentMode.toUpperCase();
            if (maxLbl) maxLbl.textContent = maxMembers;

            if (currentMode === "grupos") {
                if (formInd) formInd.classList.add('d-none');
                if (formGrp) formGrp.classList.remove('d-none');
                let container = document.getElementById('members-inputs-container');
                if (container && container.children.length === 0) {
                    agregarCampoIntegrante();
                }
            } else {
                if (formInd) formInd.classList.remove('d-none');
                if (formGrp) formGrp.classList.add('d-none');
            }
        }

        function agregarCampoIntegrante() {
            let container = document.getElementById('members-inputs-container');
            if (container.children.length >= maxMembers) {
                alert("Límite máximo de " + maxMembers + " integrantes alcanzado.");
                return;
            }
            let input = document.createElement('input');
            input.type = "text";
            input.className = "form-control mb-2 member-input";
            input.placeholder = "Nombre del integrante " + (container.children.length + 1);
            container.appendChild(input);
        }

function unirseSala() {
            let name = "";
            if (currentMode === "individual") {
                name = document.getElementById('player-name').value.trim();
                if (!name) return alert("Ingresa tu nombre");
                ws.send("JOIN_INDIVIDUAL:" + name);
            } else {
                name = document.getElementById('team-name').value.trim();
                if (!name) return alert("Ingresa el nombre del equipo");

                let inputs = document.querySelectorAll('.member-input');
                let members = [];
                inputs.forEach(inp => {
                    if (inp.value.trim()) members.push(inp.value.trim());
                });

                if (members.length === 0) return alert("Agrega al menos un integrante.");
                ws.send("JOIN_TEAM:" + name + ":" + members.join(","));
            }

            // Guardar el nombre localmente para llevarlo a estudiante.jsp
            localStorage.setItem("nombreJugador", name);

            document.getElementById('player-login-box').classList.add('d-none');
            document.getElementById('player-waiting-box').classList.remove('d-none');
        }

        function parseStateUpdate(msg) {
            let data = msg.substring(13);
            let parts = data.split(";");
            let teamsPart = parts[2] ? parts[2].replace("TEAMS:", "") : "";
            let teams = teamsPart ? teamsPart.split("|") : [];

            let hostList = document.getElementById('host-participants-list');
            if (hostList) {
                hostList.innerHTML = "";
                teams.forEach(t => {
                    let li = document.createElement('li');
                    li.className = "list-group-item";
                    li.textContent = t;
                    hostList.appendChild(li);
                });
            }

            let playerList = document.getElementById('player-participants-list');
            if (playerList) {
                playerList.innerHTML = "";
                teams.forEach(t => {
                    let li = document.createElement('li');
                    li.className = "list-group-item";
                    li.textContent = t;
                    playerList.appendChild(li);
                });
            }
        }

        function iniciarJuegoHost() {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send("START_GAME");
            } else {
                alert("No hay conexión activa con el servidor.");
            }
        }
    </script>
</body>
</html>