import { useEffect, useState } from "react";
import { addItems, uploadMedia } from "./api/client";
import BrowseView from "./features/browse/BrowseView";
import CategoryView from "./features/category/CategoryView";
import CollectionView from "./features/collection/CollectionView";
import HomeView from "./features/home/HomeView";
import LibraryView from "./features/library/LibraryView";
import Sidebar from "./layout/Sidebar";
import TabBar from "./layout/TabBar";
import { notify, onNotice, run } from "./lib/notify";
import type { View } from "./lib/view";

export default function App() {
  const [view, setView] = useState<View>({ kind: "home" });
  const [version, setVersion] = useState(0);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState("");

  const refresh = () => setVersion((v) => v + 1);

  useEffect(() => onNotice(setNotice), []);

  useEffect(() => {
    if (!notice) return;
    const t = setTimeout(() => setNotice(""), 3500);
    return () => clearTimeout(t);
  }, [notice]);

  const navigate = (v: View) => {
    setView(v);
    window.scrollTo(0, 0);
  };

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

  const uploadLabel = busy ? "Uploading…" : view.kind === "collection" ? "Upload here" : "Upload";
  const props = { version, onNavigate: navigate, onChanged: refresh };

  return (
    <div className="shell">
      <header className="top">
        <h1>
          <button type="button" onClick={() => navigate({ kind: "home" })}>archeic</button>
        </h1>
        <label className="upload">
          {uploadLabel}
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
        {view.kind === "home" && <HomeView version={version} onNavigate={navigate} />}
        {view.kind === "library" && <LibraryView version={version} onChanged={refresh} />}
        {view.kind === "browse" && <BrowseView {...props} />}
        {view.kind === "category" && <CategoryView key={view.id} id={view.id} {...props} />}
        {view.kind === "collection" && <CollectionView key={view.id} id={view.id} {...props} />}
      </main>

      <TabBar view={view} busy={busy} uploadLabel={uploadLabel} onNavigate={navigate} onUpload={onUpload} />

      {notice && (
        <div className="toast" role="status">
          {notice}
        </div>
      )}
    </div>
  );
}
