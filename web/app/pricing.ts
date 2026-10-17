export const roomRates = {
  "Garden Queen": 45_000,
  "Courtyard Twin": 50_000,
  "Deluxe King": 65_000,
  "Harbor Suite": 125_000,
} as const;

export const roomCapacities: Record<string, number> = {
  "Garden Queen": 2,
  "Courtyard Twin": 2,
  "Deluxe King": 2,
  "Harbor Suite": 4,
};