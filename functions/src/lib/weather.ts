// Weather state + drone speed modifier.
// Spec: §8 sim engine.

export type WeatherState = "clear" | "rain" | "storm";

export function speedMod(state: WeatherState): number {
  switch (state) {
    case "clear": return 1.0;
    case "rain":  return 0.85;
    case "storm": return 0.6;
  }
}
