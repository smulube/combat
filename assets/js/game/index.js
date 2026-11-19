export function startGame() {
  const canvas = document.getElementById("game-canvas");
  if (!canvas) {
    return;
  }

  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "blue";
  ctx.fillRect(10, 10, 20, 20);
}
