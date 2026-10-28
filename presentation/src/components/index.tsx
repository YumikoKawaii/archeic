import { useEffect, useState, type FormEvent, type ReactNode } from "react";
import { contentUrl, Kind, type Media } from "../api/client";
import Icon, { type IconName } from "./Icon";

export { Icon };
export type { IconName };

export function Thumb({ media }: { media: Media }) {
  return media.kind === Kind.IMAGE ? (
    <img src={contentUrl(media.id)} alt={media.name} loading="lazy" draggable={false} />
  ) : (
    <video src={`${contentUrl(media.id)}#t=0.1`} preload="metadata" muted playsInline />
  );
}

interface PageHeaderProps {
  title: string;
  subtitle?: string;
  back?: () => void;
  actions?: ReactNode;
  children?: ReactNode;
}

export function PageHeader({ title, subtitle, back, actions, children }: PageHeaderProps) {
  return (
    <header className="page-head">
      <div className="ph-row">
        {back && (
          <button type="button" className="icon-btn back" aria-label="Back" onClick={back}>
            <Icon name="back" />
          </button>
        )}
        <div className="ph-titles">
          <h2>{title}</h2>
          {subtitle && <p>{subtitle}</p>}
        </div>
        {actions && <div className="ph-actions">{actions}</div>}
      </div>
      {children}
    </header>
  );
}

export function IconButton({ icon, label, onClick }: { icon: IconName; label: string; onClick: () => void }) {
  return (
    <button type="button" className="icon-btn" aria-label={label} title={label} onClick={onClick}>
      <Icon name={icon} />
    </button>
  );
}

interface SegmentedProps<T> {
  value: T;
  options: [T, string][];
  onChange: (v: T) => void;
}

export function Segmented<T extends string | number>({ value, options, onChange }: SegmentedProps<T>) {
  return (
    <div className="seg" role="tablist">
      {options.map(([v, label]) => (
        <button key={String(v)} type="button" role="tab" aria-selected={v === value} className={v === value ? "on" : ""} onClick={() => onChange(v)}>
          {label}
        </button>
      ))}
    </div>
  );
}

interface EmptyStateProps {
  icon: IconName;
  title: string;
  text: string;
  action?: ReactNode;
}

export function EmptyState({ icon, title, text, action }: EmptyStateProps) {
  return (
    <div className="empty-state">
      <span className="empty-icon"><Icon name={icon} size={30} /></span>
      <h3>{title}</h3>
      <p>{text}</p>
      {action}
    </div>
  );
}

interface ConfirmButtonProps {
  label: string;
  icon?: IconName;
  disabled?: boolean;
  onConfirm: () => void;
}

export function ConfirmButton({ label, icon, disabled, onConfirm }: ConfirmButtonProps) {
  const [armed, setArmed] = useState(false);

  useEffect(() => {
    if (!armed) return;
    const t = setTimeout(() => setArmed(false), 3000);
    return () => clearTimeout(t);
  }, [armed]);

  return (
    <button
      type="button"
      disabled={disabled}
      aria-label={armed ? `Confirm ${label.toLowerCase()}` : label}
      className={armed ? "danger armed" : "danger"}
      onClick={() => (armed ? onConfirm() : setArmed(true))}
    >
      {icon && <Icon name={icon} />}
      <span>{armed ? "Tap again" : label}</span>
    </button>
  );
}

export function Sheet({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="sheet" onClick={onClose}>
      <div className="sheet-panel" role="dialog" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <span className="sheet-handle" aria-hidden="true" />
        <h2>{title}</h2>
        {children}
      </div>
    </div>
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
      <div className="form-actions">
        <button type="button" className="btn" onClick={onCancel}>Cancel</button>
        <button type="submit" className="btn primary" disabled={!name.trim()}>{submit}</button>
      </div>
    </form>
  );
}
