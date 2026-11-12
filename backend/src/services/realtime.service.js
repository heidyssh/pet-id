let ioActual = null;

export function configurarRealtime(io) {
  ioActual = io;
}

export function emitirAUsuario(idUsuario, evento, datos) {
  ioActual?.to(`usuario:${idUsuario}`).emit(evento, datos);
}
