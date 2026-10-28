import { timestampDate } from "@bufbuild/protobuf/wkt";
import type { Media } from "../api/client";

export interface Section {
  label: string;
  items: { m: Media; i: number }[];
}

export function groupByDay(items: Media[]): Section[] {
  const out: Section[] = [];
  items.forEach((m, i) => {
    const label = m.createTime ? dayLabel(timestampDate(m.createTime)) : "Undated";
    const last = out[out.length - 1];
    if (last && last.label === label) last.items.push({ m, i });
    else out.push({ label, items: [{ m, i }] });
  });
  return out;
}

function dayLabel(d: Date): string {
  const start = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const days = Math.round((start(new Date()) - start(d)) / 86_400_000);
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days > 1 && days < 7) return d.toLocaleDateString(undefined, { weekday: "long" });
  const sameYear = d.getFullYear() === new Date().getFullYear();
  return d.toLocaleDateString(
    undefined,
    sameYear ? { day: "numeric", month: "long" } : { day: "numeric", month: "long", year: "numeric" },
  );
}

export function countLabel(items: Media[], imageKind: number): string {
  const images = items.filter((m) => m.kind === imageKind).length;
  const videos = items.length - images;
  const parts = [];
  if (images) parts.push(`${images} ${images === 1 ? "photo" : "photos"}`);
  if (videos) parts.push(`${videos} ${videos === 1 ? "video" : "videos"}`);
  return parts.join(" · ") || "Empty";
}
