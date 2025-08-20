// 协作者光标组件

import type { Collaborator } from '@cardmind/types';
import './CollaboratorCursors.css';

interface CollaboratorCursorsProps {
  collaborators: Collaborator[];
}

export default function CollaboratorCursors({ collaborators }: CollaboratorCursorsProps) {
  if (collaborators.length === 0) {
    return null;
  }

  return (
    <div className="collaborator-cursors">
      {collaborators.map(collaborator => (
        <div
          key={collaborator.id}
          className="collaborator-cursor"
          style={{
            left: collaborator.cursor?.x || 0,
            top: collaborator.cursor?.y || 0,
            backgroundColor: collaborator.color
          }}
          title={`${collaborator.name} - ${new Date(collaborator.lastActive).toLocaleTimeString()}`}
        >
          <div className="cursor-indicator" />
          <div 
            className="cursor-label"
            style={{ backgroundColor: collaborator.color }}
          >
            {collaborator.name}
          </div>
        </div>
      ))}
    </div>
  );
}