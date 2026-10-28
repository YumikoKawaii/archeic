import { useCallback, useEffect, useRef, useState, type PointerEvent, type WheelEvent } from "react";

const MIN = 1;
const MAX = 8;
const STEP = 1.5;

interface Zoom {
  scale: number;
  x: number;
  y: number;
}

const initial: Zoom = { scale: 1, x: 0, y: 0 };

export default function ZoomImage({ src, alt }: { src: string; alt: string }) {
  const stage = useRef<HTMLDivElement>(null);
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const pinch = useRef<{ dist: number; zoom: Zoom } | null>(null);
  const [zoom, setZoom] = useState<Zoom>(initial);

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

  const onWheel = (e: WheelEvent) => {
    const p = toLocal(e.clientX, e.clientY);
    setZoom((z) => zoomAt(z, z.scale * Math.exp(-e.deltaY * 0.0015), p.x, p.y));
  };

  const onDoubleClick = (e: { clientX: number; clientY: number }) => {
    const p = toLocal(e.clientX, e.clientY);
    setZoom((z) => (z.scale > 1 ? initial : zoomAt(z, 2.5, p.x, p.y)));
  };

  const onPointerDown = (e: PointerEvent) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.current.size === 2) {
      const [a, b] = [...pointers.current.values()];
      pinch.current = { dist: Math.hypot(a.x - b.x, a.y - b.y), zoom };
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

    if (pointers.current.size === 1) {
      const dx = e.clientX - prev.x;
      const dy = e.clientY - prev.y;
      setZoom((z) => (z.scale > 1 ? { ...z, x: z.x + dx, y: z.y + dy } : z));
    }
  };

  const onPointerUp = (e: PointerEvent) => {
    pointers.current.delete(e.pointerId);
    if (pointers.current.size < 2) pinch.current = null;
  };

  return (
    <div
      ref={stage}
      className={zoom.scale > 1 ? "zoom zoomed" : "zoom"}
      onWheel={onWheel}
      onDoubleClick={onDoubleClick}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      <img
        src={src}
        alt={alt}
        draggable={false}
        style={{ transform: `translate(${zoom.x}px, ${zoom.y}px) scale(${zoom.scale})` }}
      />
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
