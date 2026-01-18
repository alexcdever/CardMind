import { useState } from 'react';
import { Card, CardContent, CardHeader } from './ui/card';
import { Input } from './ui/input';
import { Textarea } from './ui/textarea';
import { Badge } from './ui/badge';
import { Button } from './ui/button';
import { Trash2, Edit2, Check, X, Users, MoreVertical } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from './ui/dropdown-menu';

export interface Note {
  id: string;
  title: string;
  content: string;
  tags: string[];
  createdAt: number;
  updatedAt: number;
  lastEditDevice?: string;
  isEditing?: boolean;
}

interface NoteCardProps {
  note: Note;
  currentDevice: string;
  onUpdate: (note: Note) => void;
  onDelete: (id: string) => void;
}

export function NoteCard({ note, currentDevice, onUpdate, onDelete }: NoteCardProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(note.title);
  const [editContent, setEditContent] = useState(note.content);
  const [newTag, setNewTag] = useState('');

  const handleSave = () => {
    onUpdate({
      ...note,
      title: editTitle,
      content: editContent,
      updatedAt: Date.now(),
      lastEditDevice: currentDevice,
    });
    setIsEditing(false);
  };

  const handleCancel = () => {
    setEditTitle(note.title);
    setEditContent(note.content);
    setIsEditing(false);
  };

  const handleAddTag = () => {
    if (newTag.trim() && !note.tags.includes(newTag.trim())) {
      onUpdate({
        ...note,
        tags: [...note.tags, newTag.trim()],
        updatedAt: Date.now(),
        lastEditDevice: currentDevice,
      });
      setNewTag('');
    }
  };

  const handleRemoveTag = (tag: string) => {
    onUpdate({
      ...note,
      tags: note.tags.filter((t) => t !== tag),
      updatedAt: Date.now(),
      lastEditDevice: currentDevice,
    });
  };

  const isEditedByOther = note.lastEditDevice && note.lastEditDevice !== currentDevice;

  return (
    <Card className="group hover:shadow-lg transition-all cursor-pointer active:scale-[0.98]">
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between gap-2">
          {isEditing ? (
            <Input
              value={editTitle}
              onChange={(e) => setEditTitle(e.target.value)}
              placeholder="笔记标题"
              className="flex-1"
              autoFocus
            />
          ) : (
            <h3 className="flex-1 line-clamp-2">{note.title || '无标题笔记'}</h3>
          )}
          <div className="flex items-center gap-1">
            {isEditedByOther && (
              <Users className="size-4 text-blue-500" title={`最后编辑: ${note.lastEditDevice}`} />
            )}
            {isEditing ? (
              <>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={handleSave}
                  className="size-8"
                >
                  <Check className="size-4 text-green-600" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={handleCancel}
                  className="size-8"
                >
                  <X className="size-4 text-red-600" />
                </Button>
              </>
            ) : (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-8 lg:opacity-0 lg:group-hover:opacity-100 transition-opacity"
                  >
                    <MoreVertical className="size-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => setIsEditing(true)}>
                    <Edit2 className="size-4 mr-2" />
                    编辑
                  </DropdownMenuItem>
                  <DropdownMenuItem 
                    onClick={() => onDelete(note.id)}
                    className="text-destructive"
                  >
                    <Trash2 className="size-4 mr-2" />
                    删除
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            )}
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {isEditing ? (
          <Textarea
            value={editContent}
            onChange={(e) => setEditContent(e.target.value)}
            placeholder="笔记内容"
            rows={5}
            className="resize-none"
          />
        ) : (
          <p className="text-muted-foreground whitespace-pre-wrap line-clamp-4 min-h-[80px]">
            {note.content || '空笔记'}
          </p>
        )}
        
        <div className="flex flex-wrap gap-2 items-center">
          {note.tags.map((tag) => (
            <Badge
              key={tag}
              variant="secondary"
              className="cursor-pointer hover:bg-destructive hover:text-destructive-foreground transition-colors"
              onClick={() => handleRemoveTag(tag)}
            >
              {tag} ×
            </Badge>
          ))}
          {isEditing && (
            <div className="flex gap-1">
              <Input
                value={newTag}
                onChange={(e) => setNewTag(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleAddTag()}
                placeholder="添加标签"
                className="h-6 px-2 text-xs w-24"
              />
              <Button
                size="sm"
                variant="ghost"
                onClick={handleAddTag}
                className="h-6 px-2 text-xs"
              >
                +
              </Button>
            </div>
          )}
        </div>

        <div className="text-xs text-muted-foreground">
          {note.lastEditDevice && (
            <span className="mr-2">设备: {note.lastEditDevice}</span>
          )}
          <span>更新: {new Date(note.updatedAt).toLocaleString('zh-CN')}</span>
        </div>
      </CardContent>
    </Card>
  );
}