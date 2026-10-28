import { useEffect, useState } from "react";
import { addItems, uploadMedia } from "./api/client";
import CategoryView from "./features/category/CategoryView";
import CollectionView from "./features/collection/CollectionView";
import LibraryView from "./features/library/LibraryView";
import { notify, onNotice, run } from "./lib/notify";
import Sidebar from "./layout/Sidebar";
import type { View } from "./lib/view";

export default function App() {
  const [view, setView] = useState<View>({ kind: "library" });
  const [version, setVersion] = useState(0);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");

  const refresh = () => setVersion((v) => v + 1);

  useEffect(() => onNotice(setNotice), []);

  useEffect(() => {
    if (!notice) return;
    const t = setTimeout(() => setNotice(""), 4000);
    return () => clearTimeout(t);
  }, [notice]);

  const onUpload = async (files: FileList | null) => {
    if (!files?.length) return;
    const target = view.kind === "collection" ? view.id : "";
    setBusy(true);
    await run(async () => {
      const ids: string[] = [];
      for (const f of Array.from(files)) ids.push(await uploadMedia(f));
      if (target) await addItems(target, ids);
      notify(`Uploaded ${ids.length} ${ids.length === 1 ? "file" : "files"}`);
    });
    setBusy(false);
    refresh();
  };

  const props = { version, onNavigate: setView, onChanged: refresh };

  return (
    <div className="shell">
      <header className="top">
        <h1>
          <button type="button" onClick={() => setView({ kind: "library" })}>archeic</button>
        </h1>
        <label className="upload">
          {busy ? "Uploading…" : view.kind === "collection" ? "Upload here" : "Upload"}
          <input
            id="upload"
            type="file"
            multiple
            accept="image/*,video/*"
            hidden
            disabled={busy}
            onChange={(e) => {
              onUpload(e.target.files);
              e.target.value = "";
            }}
          />
        </label>
      </header>

      <Sidebar view={view} {...props} />

      <main className="content">
        {view.kind === "library" && <LibraryView version={version} onChanged={refresh} />}
        {view.kind === "category" && <CategoryView key={view.id} id={view.id} {...props} />}
        {view.kind === "collection" && <CollectionView key={view.id} id={view.id} {...props} />}
      </main>

      {notice && (
        <div className="toast" role="status">
          {notice}
        </div>
      )}
    </div>
  );
}
