// Flight simulator math. Pure functions, no Firestore access.
// Spec: §8 sim engine, §10 tickFlights.

import { haversineKm } from "./geo";
import { speedMod, type WeatherState } from "./weather";

const DELIVERING_HOLD_MS = 60_000;
const BATTERY_DRAIN_PER_KM = 1.5;

export type FlightState = {
  origin: { lat: number; lng: number };
  destination: { lat: number; lng: number };
  takeoffAt: number;
  speedKmh: number;
  weatherModifierAtTakeoff: number;
  batteryAtTakeoff: number;
};

export type FlightSnapshot = {
  progress: number;
  battery: number;
};

export function computeEta(args: {
  origin: { lat: number; lng: number };
  destination: { lat: number; lng: number };
  takeoffAt: number;
  speedKmh: number;
  weatherModifierAtTakeoff: number;
  batteryAtTakeoff: number;
}): number {
  const distKm = haversineKm(args.origin, args.destination);
  const effectiveKmh = Math.max(1, args.speedKmh * args.weatherModifierAtTakeoff);
  const hours = distKm / effectiveKmh;
  return args.takeoffAt + Math.round(hours * 3600 * 1000);
}

export function snapshot(state: FlightState, nowMs: number, weather: WeatherState): FlightSnapshot {
  const distKm = haversineKm(state.origin, state.destination);
  const effectiveKmh = Math.max(1, state.speedKmh * speedMod(weather));
  const elapsedHours = Math.max(0, (nowMs - state.takeoffAt) / (3600 * 1000));
  const traveledKm = Math.min(distKm, elapsedHours * effectiveKmh);
  const progress = distKm === 0 ? 1 : traveledKm / distKm;
  const battery = Math.max(0, state.batteryAtTakeoff - traveledKm * BATTERY_DRAIN_PER_KM);
  return { progress, battery };
}

export function deliveringHoldElapsed(startMs: number, nowMs: number): boolean {
  return nowMs - startMs >= DELIVERING_HOLD_MS;
}

export function rollAbort(args: {
  weather: WeatherState;
  battery: number;
}): "weather" | "battery" | "mechanical" | null {
  if (args.battery <= 5) return "battery";
  const stormHit = args.weather === "storm" && Math.random() < 0.03;
  if (stormHit) return "weather";
  const mechHit = Math.random() < 0.002;
  if (mechHit) return "mechanical";
  return null;
}
