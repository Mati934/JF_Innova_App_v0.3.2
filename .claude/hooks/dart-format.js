// Hook PostToolUse (Edit|Write): formatea con `dart format` el archivo .dart
// que Claude acaba de editar. Lee el JSON del hook por stdin (no hay jq en
// Windows). Nunca bloquea: si algo falla, sale en silencio.
const { execFileSync } = require('child_process');

let input = '';
process.stdin.on('data', (chunk) => (input += chunk));
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const file =
      (data.tool_input && data.tool_input.file_path) ||
      (data.tool_response && data.tool_response.filePath) ||
      '';
    if (!file.endsWith('.dart')) return;
    // dart es un .bat en Windows: se invoca a traves de cmd.
    execFileSync('cmd', ['/c', 'dart', 'format', file], { stdio: 'ignore' });
  } catch (_) {
    // Sin formato antes que romper el flujo de edicion.
  }
});
