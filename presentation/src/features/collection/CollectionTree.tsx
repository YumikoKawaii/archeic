import { useEffect, useState } from "react";
import { listCollections, type Collection } from "../../api/client";
import { run } from "../../lib/notify";

interface Props {
  categoryId: string;
  parentId?: string;
  depth?: number;
  version: number;
  current?: string;
  onOpen: (c: Collection) => void;
}

export default function CollectionTree({ categoryId, parentId, depth = 1, version, current, onOpen }: Props) {
  const [items, setItems] = useState<Collection[]>([]);

  useEffect(() => {
    run(async () => setItems(await listCollections(categoryId, parentId)));
  }, [categoryId, parentId, version]);

  if (items.length === 0) return null;

  return (
    <ul className="tree">
      {items.map((c) => (
        <Node key={c.id} c={c} depth={depth} version={version} current={current} onOpen={onOpen} />
      ))}
    </ul>
  );
}

interface NodeProps {
  c: Collection;
  depth: number;
  version: number;
  current?: string;
  onOpen: (c: Collection) => void;
}

function Node({ c, depth, version, current, onOpen }: NodeProps) {
  const [open, setOpen] = useState(false);

  return (
    <li>
      <div className={current === c.id ? "node on" : "node"} style={{ paddingLeft: depth * 14 }}>
        <button type="button" className="caret" aria-label={open ? "Collapse" : "Expand"} onClick={() => setOpen(!open)}>
          {open ? "▾" : "▸"}
        </button>
        <button type="button" className="label" onClick={() => onOpen(c)}>
          {c.name}
        </button>
      </div>
      {open && (
        <CollectionTree
          categoryId={c.categoryId}
          parentId={c.id}
          depth={depth + 1}
          version={version}
          current={current}
          onOpen={onOpen}
        />
      )}
    </li>
  );
}
