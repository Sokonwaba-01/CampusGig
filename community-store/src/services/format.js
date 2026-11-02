export function formatPrice(value) {
  return `R${Number(value || 0).toFixed(2)}`;
}

export function formatDate(value, withTime = false) {
  if (!value) return "";

  return new Date(value).toLocaleString("en-ZA", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
  });
}

export function stars(value) {
  const rating = Math.max(0, Math.min(5, Math.round(Number(value) || 0)));
  return "★".repeat(rating) + "☆".repeat(5 - rating);
}
