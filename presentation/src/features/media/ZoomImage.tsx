import { useCallback, useEffect, useRef, useState, type PointerEvent, type WheelEvent } from "react";

const MIN = 1;
const MAX = 8;
const STEP = 1.5;
const SWIPE = 60;
const DOUBLE_TAP_MS = 280;

interface Zoom {
  scale: number;
  x: number;
  y: number;
}

export type SwipeDirection = "left" | "right" | "down";

const initial: Zoom = { scale: 1, x: 0, y: 0 };

interface Props {
  src: string;
  alt: string;
  onSwipe: (dir: SwipeDirection) => void;
}

export default function ZoomImage({ src, alt, onSwipe }: Props) {
  const stage = useRef<HTMLDivElement>(null);
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const pinch = useRef<{ dist: number; zoom: Zoom } | null>(null);
  const start = useRef<{ x: number; y: number } | null>(null);
  const lastTap = useRef(0);
  const [zoom, setZoom] = useState<Zoom>(initial);
  const [swipe, setSwipe] = useState({ dx: 0, dy: 0 });

  const toLocal = (clientX: number, clientY: number) => {
    const r = stage.current!.getBoundingClientRect();
    return { x: clientX - r.left - r.width / 2, y: clientY - r.top - r.height / 2 };
  };

  const zoomAt = useCallback((from: Zoom, next: number, px = 0, py = 0): Zoom => {
    const scale = Math.min(MAX, Math.max(MIN, next));
    if (scale === MIN) return initial;
    const k = scale / from.scale;
    return { scale, x: px - (px - from.x) * k, y: py - (py - from.y) * k };
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "+" || e.key === "=") setZoom((z) => zoomAt(z, z.scale * STEP));
      if (e.key === "-") setZoom((z) => zoomAt(z, z.scale / STEP));
      if (e.key === "0") setZoom(initial);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [zoomAt]);

  const toggleAt = (clientX: number, clientY: number) => {
    const p = toLocal(clientX, clientY);
    setZoom((z) => (z.scale > 1 ? initial : zoomAt(z, 2.5, p.x, p.y)));
  };

  const onWheel = (e: WheelEvent) => {
    const p = toLocal(e.clientX, e.clientY);
    setZoom((z) => zoomAt(z, z.scale * Math.exp(-e.deltaY * 0.0015), p.x, p.y));
  };

  const onPointerDown = (e: PointerEvent) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.current.size === 1) start.current = { x: e.clientX, y: e.clientY };
    if (pointers.current.size === 2) {
      const [a, b] = [...pointers.current.values()];
      pinch.current = { dist: Math.hypot(a.x - b.x, a.y - b.y), zoom };
      start.current = null;
      setSwipe({ dx: 0, dy: 0 });
    }
  };

  const onPointerMove = (e: PointerEvent) => {
    const prev = pointers.current.get(e.pointerId);
    if (!prev) return;
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });

    if (pointers.current.size === 2 && pinch.current) {
      const [a, b] = [...pointers.current.values()];
      const mid = toLocal((a.x + b.x) / 2, (a.y + b.y) / 2);
      const ratio = Math.hypot(a.x - b.x, a.y - b.y) / pinch.current.dist;
      setZoom(zoomAt(pinch.current.zoom, pinch.current.zoom.scale * ratio, mid.x, mid.y));
      return;
    }

    if (pointers.current.size !== 1) return;
    if (zoom.scale > 1) {
      const dx = e.clientX - prev.x;
      const dy = e.clientY - prev.y;
      setZoom((z) => ({ ...z, x: z.x + dx, y: z.y + dy }));
    } else if (start.current && e.pointerType !== "mouse") {
      setSwipe({ dx: e.clientX - start.current.x, dy: Math.max(0, e.clientY - start.current.y) });
    }
  };

  const onPointerUp = (e: PointerEvent) => {
    pointers.current.delete(e.pointerId);
    if (pointers.current.size < 2) pinch.current = null;
    if (pointers.current.size > 0 || !start.current) return;

    const dx = e.clientX - start.current.x;
    const dy = e.clientY - start.current.y;
    start.current = null;
    setSwipe({ dx: 0, dy: 0 });

    const moved = Math.hypot(dx, dy) > 10;
    if (!moved && e.pointerType !== "mouse") {
      const now = Date.now();
      if (now - lastTap.current < DOUBLE_TAP_MS) {
        toggleAt(e.clientX, e.clientY);
        lastTap.current = 0;
      } else {
        lastTap.current = now;
      }
      return;
    }
    if (zoom.scale > 1 || e.pointerType === "mouse") return;
    if (Math.abs(dx) > SWIPE && Math.abs(dx) > Math.abs(dy)) onSwipe(dx < 0 ? "left" : "right");
    else if (dy > SWIPE * 1.5) onSwipe("down");
  };

  const swiping = swipe.dx !== 0 || swipe.dy !== 0;
  const transform = swiping
    ? `translate(${swipe.dx}px, ${swipe.dy}px) scale(${1 - Math.min(swipe.dy, 300) / 1500})`
    : `translate(${zoom.x}px, ${zoom.y}px) scale(${zoom.scale})`;

  return (
    <div
      ref={stage}
      className={[zoom.scale > 1 ? "zoom zoomed" : "zoom", swiping && "swiping"].filter(Boolean).join(" ")}
      onWheel={onWheel}
      onDoubleClick={(e) => toggleAt(e.clientX, e.clientY)}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      <img src={src} alt={alt} draggable={false} style={{ transform }} />
      <div className="zoom-ctrl" onPointerDown={(e) => e.stopPropagation()} onDoubleClick={(e) => e.stopPropagation()}>
        <button type="button" aria-label="Zoom out" disabled={zoom.scale <= MIN} onClick={() => setZoom((z) => zoomAt(z, z.scale / STEP))}>−</button>
        <button type="button" className="zoom-level" aria-label="Reset zoom" onClick={() => setZoom(initial)}>
          {Math.round(zoom.scale * 100)}%
        </button>
        <button type="button" aria-label="Zoom in" disabled={zoom.scale >= MAX} onClick={() => setZoom((z) => zoomAt(z, z.scale * STEP))}>+</button>
      </div>
    </div>
  );
}
