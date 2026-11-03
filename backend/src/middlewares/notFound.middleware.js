
export function notFoundMiddleware(req, res) {
  return res.status(404).json({
    success: false,
    message: 'La ruta solicitada no existe',
  });
}
