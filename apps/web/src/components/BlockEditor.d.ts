import type { AnyBlock } from '@cardmind/types';
import './BlockEditor.css';
interface BlockEditorProps {
    block: AnyBlock;
    onSave: (block: AnyBlock) => void;
    onCancel: () => void;
}
export default function BlockEditor({ block, onSave, onCancel }: BlockEditorProps): import("react/jsx-runtime").JSX.Element;
export {};
//# sourceMappingURL=BlockEditor.d.ts.map