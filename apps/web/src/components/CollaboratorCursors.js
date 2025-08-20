import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import './CollaboratorCursors.css';
export default function CollaboratorCursors({ collaborators }) {
    if (collaborators.length === 0) {
        return null;
    }
    return (_jsx("div", { className: "collaborator-cursors", children: collaborators.map(collaborator => (_jsxs("div", { className: "collaborator-cursor", style: {
                left: collaborator.cursor?.x || 0,
                top: collaborator.cursor?.y || 0,
                backgroundColor: collaborator.color
            }, title: `${collaborator.name} - ${new Date(collaborator.lastActive).toLocaleTimeString()}`, children: [_jsx("div", { className: "cursor-indicator" }), _jsx("div", { className: "cursor-label", style: { backgroundColor: collaborator.color }, children: collaborator.name })] }, collaborator.id))) }));
}
//# sourceMappingURL=CollaboratorCursors.js.map