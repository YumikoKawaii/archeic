import { useEffect, useState, type FormEvent, type ReactNode } from "react";
import { contentUrl, Kind, type Media } from "../api/client";

export function Thumb({ media }: { media: Media }) {
  return media.kind === Kind.IMAGE ? (
    <img src={contentUrl(media.id)} alt={media.name} loading="lazy" />
  ) : (
    <video src={`${contentUrl(media.id)}#t=0.1`} preload="metadata" muted />
  );
}

export function ConfirmButton({ label, onConfirm }: { label: string; onConfirm: () => void }) {
  const [armed, setArmed] = useState(false);

  useEffect(() => {
    if (!armed) return;
    const t = setTimeout(() => setArmed(false), 3000);
    return () => clearTimeout(t);
  }, [armed]);

  return (
    <button
      type="button"
      className={armed ? "danger armed" : "danger"}
      onClick={() => (armed ? onConfirm() : setArmed(true))}
    >
      {armed ? `Confirm ${label.toLowerCase()}` : label}
    </button>
  );
}

interface NameFormProps {
  id: string;
  placeholder: string;
  submit: string;
  onSubmit: (name: string) => Promise<boolean>;
  onCancel: () => void;
  children?: ReactNode;
}

export function NameForm({ id, placeholder, submit, onSubmit, onCancel, children }: NameFormProps) {
  const [name, setName] = useState("");

  const handle = async (e: FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;
    if (await onSubmit(name.trim())) setName("");
  };

  return (
    <form className="name-form" onSubmit={handle}>
      <input
        id={id}
        autoFocus
        value={name}
        placeholder={placeholder}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) => e.key === "Escape" && onCancel()}
      />
      {children}
      <div className="row">
        <button type="submit" className="primary">{submit}</button>
        <button type="button" onClick={onCancel}>Cancel</button>
      </div>
    </form>
  );
}
