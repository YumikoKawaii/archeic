import { useEffect, useState } from "react";
import { createCollection, deleteCategory, getCategory, layoutLabels, listCollections, type Category, type Collection } from "../../api/client";
import CollectionCard from "../../features/collection/CollectionCard";
import { ConfirmButton, NameForm } from "../../components";
import { notify, run } from "../../lib/notify";
import type { View } from "../../lib/view";

interface Props {
  id: string;
  version: number;
  onNavigate: (v: View) => void;
  onChanged: () => void;
}

export default function CategoryView({ id, version, onNavigate, onChanged }: Props) {
  const [category, setCategory] = useState<Category>();
  const [collections, setCollections] = useState<Collection[]>([]);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    run(async () => {
      setCategory(await getCategory(id));
      setCollections(await listCollections(id));
    });
  }, [id, version]);

  if (!category) return null;

  const layout = layoutLabels.find(([l]) => l === category.layout)?.[1] ?? "Gallery";

  return (
    <section className="page">
      <header className="page-head">
        <div>
          <span className="eyebrow">{layout} category</span>
          <h2>{category.name}</h2>
        </div>
        <div className="row">
          <button type="button" className="primary" onClick={() => setAdding(true)}>New collection</button>
          <ConfirmButton
            label="Delete category"
            onConfirm={() =>
              run(async () => {
                await deleteCategory(id);
                notify(`Deleted ${category.name}`);
                onNavigate({ kind: "library" });
                onChanged();
              })
            }
          />
        </div>
      </header>

      {adding && (
        <NameForm
          id="new-collection"
          placeholder="Collection name"
          submit="Create"
          onCancel={() => setAdding(false)}
          onSubmit={(name) =>
            run(async () => {
              await createCollection(id, name);
              setAdding(false);
              onChanged();
            })
          }
        />
      )}

      {collections.length === 0 ? (
        <p className="empty">No collections in {category.name} yet. Create one, then add media to it from the library.</p>
      ) : (
        <div className="cards">
          {collections.map((c) => (
            <CollectionCard key={c.id} c={c} version={version} onOpen={() => onNavigate({ kind: "collection", id: c.id })} />
          ))}
        </div>
      )}
    </section>
  );
}
