import { useEffect, useState } from "react";
import { createCategory, Layout, layoutLabels, listCategories, listCollections, type Category, type Collection } from "../../api/client";
import { EmptyState, Icon, IconButton, NameForm, PageHeader, Sheet } from "../../components";
import { run } from "../../lib/notify";
import type { View } from "../../lib/view";
import CollectionCard from "../collection/CollectionCard";

interface Props {
  version: number;
  onNavigate: (v: View) => void;
  onChanged: () => void;
}

export default function BrowseView({ version, onNavigate, onChanged }: Props) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [adding, setAdding] = useState(false);
  const [layout, setLayout] = useState<Layout>(Layout.GALLERY);

  useEffect(() => {
    run(async () => setCategories(await listCategories()));
  }, [version]);

  const add = () => setAdding(true);

  return (
    <section className="page">
      <PageHeader
        title="Collections"
        subtitle={categories.length ? `${categories.length} ${categories.length === 1 ? "category" : "categories"}` : undefined}
        actions={<IconButton icon="plus" label="New category" onClick={add} />}
      />

      {categories.length === 0 ? (
        <EmptyState
          icon="collections"
          title="Group your media"
          text="Categories hold collections, like Photos → Kyoto 2025. Start with a category."
          action={<button type="button" className="btn primary" onClick={add}>New category</button>}
        />
      ) : (
        categories.map((c) => <CategoryRow key={c.id} category={c} version={version} onNavigate={onNavigate} />)
      )}

      {adding && (
        <Sheet title="New category" onClose={() => setAdding(false)}>
          <NameForm
            id="new-category"
            placeholder="Photos, Movies, Screenshots…"
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
            <label className="field">
              <span>Shown as</span>
              <select id="new-category-layout" value={layout} onChange={(e) => setLayout(Number(e.target.value) as Layout)}>
                {layoutLabels.map(([value, label]) => (
                  <option key={value} value={value}>{label}</option>
                ))}
              </select>
            </label>
          </NameForm>
        </Sheet>
      )}
    </section>
  );
}

function CategoryRow({ category, version, onNavigate }: { category: Category; version: number; onNavigate: (v: View) => void }) {
  const [collections, setCollections] = useState<Collection[]>([]);

  useEffect(() => {
    run(async () => setCollections(await listCollections(category.id)));
  }, [category.id, version]);

  const open = () => onNavigate({ kind: "category", id: category.id });

  return (
    <section className="cat-row">
      <button type="button" className="cat-head" onClick={open}>
        <span>
          <b>{category.name}</b>
          <small>{collections.length} {collections.length === 1 ? "collection" : "collections"}</small>
        </span>
        <Icon name="chevron" size={18} />
      </button>
      {collections.length === 0 ? (
        <button type="button" className="cat-empty" onClick={open}>
          <Icon name="folderPlus" size={18} />
          Add the first collection
        </button>
      ) : (
        <div className="scroller">
          {collections.map((c) => (
            <CollectionCard key={c.id} c={c} version={version} onOpen={() => onNavigate({ kind: "collection", id: c.id })} />
          ))}
        </div>
      )}
    </section>
  );
}
