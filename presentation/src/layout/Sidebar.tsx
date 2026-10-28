import { useEffect, useState } from "react";
import { createCategory, Layout, layoutLabels, listCategories, type Category } from "../api/client";
import CollectionTree from "../features/collection/CollectionTree";
import { NameForm } from "../components";
import { run } from "../lib/notify";
import type { View } from "../lib/view";

interface Props {
  view: View;
  version: number;
  onNavigate: (v: View) => void;
  onChanged: () => void;
}

export default function Sidebar({ view, version, onNavigate, onChanged }: Props) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [open, setOpen] = useState<Set<string>>(new Set());
  const [adding, setAdding] = useState(false);
  const [layout, setLayout] = useState<Layout>(Layout.GALLERY);

  useEffect(() => {
    run(async () => setCategories(await listCategories()));
  }, [version]);

  const toggle = (id: string) =>
    setOpen((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const current = view.kind === "category" || view.kind === "collection" ? view.id : "";

  return (
    <aside className="sidebar">
      <button
        type="button"
        className={view.kind === "library" ? "side-link on" : "side-link"}
        onClick={() => onNavigate({ kind: "library" })}
      >
        Library
      </button>
      <button
        type="button"
        className={view.kind === "browse" ? "side-link on" : "side-link"}
        onClick={() => onNavigate({ kind: "browse" })}
      >
        Collections
      </button>

      <div className="side-head">
        <span>Categories</span>
        <button type="button" aria-label="New category" onClick={() => setAdding(true)}>+</button>
      </div>

      {adding && (
        <NameForm
          id="new-category"
          placeholder="Category name"
          submit="Create"
          onCancel={() => setAdding(false)}
          onSubmit={(name) =>
            run(async () => {
              const c = await createCategory(name, layout);
              setAdding(false);
              onChanged();
              if (c) onNavigate({ kind: "category", id: c.id });
            })
          }
        >
          <select id="new-category-layout" value={layout} onChange={(e) => setLayout(Number(e.target.value) as Layout)}>
            {layoutLabels.map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </NameForm>
      )}

      <ul className="tree">
        {categories.map((c) => (
          <li key={c.id}>
            <div className={current === c.id ? "node on" : "node"}>
              <button
                type="button"
                className="caret"
                aria-label={open.has(c.id) ? "Collapse" : "Expand"}
                onClick={() => toggle(c.id)}
              >
                {open.has(c.id) ? "▾" : "▸"}
              </button>
              <button type="button" className="label" onClick={() => onNavigate({ kind: "category", id: c.id })}>
                {c.name}
              </button>
            </div>
            {open.has(c.id) && (
              <CollectionTree
                categoryId={c.id}
                version={version}
                current={current}
                onOpen={(col) => onNavigate({ kind: "collection", id: col.id })}
              />
            )}
          </li>
        ))}
      </ul>

      {categories.length === 0 && !adding && (
        <p className="side-empty">No categories yet. Add one with + to start grouping media.</p>
      )}
    </aside>
  );
}
