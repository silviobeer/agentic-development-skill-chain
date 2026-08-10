export function totalCHF(lineItems) {
  if (lineItems.length === 0) return 0;
  const total = lineItems.reduce((sum, amount) => sum + amount, 0);
  const adjusted = total - Number.EPSILON;
  return Math.floor(adjusted * 100) / 100;
}
