import { useState, useEffect } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Textarea } from './ui/textarea';
import { Badge } from './ui/badge';
import { X, Check, Tag } from 'lucide-react';
import type { Note } from './note-card';

interface NoteEditorFullscreenProps {
  note: Note | null;
  currentDevice: string;
  isOpen: boolean;
  onClose: () => void;
  onSave: (note: Note) => void;
}

export function NoteEditorFullscreen({
  note,
  currentDevice,
  isOpen,
  onClose,
  onSave,
}: NoteEditorFullscreenProps) {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [tags, setTags] = useState<string[]>([]);
  const [newTag, setNewTag] = useState('');
  const [showTagInput, setShowTagInput] = useState(false);

  useEffect(() => {
    if (note) {
      setTitle(note.title);
      setContent(note.content);
      setTags(note.tags);
    } else {
      setTitle('');
      setContent('');
      setTags([]);
    }
  }, [note]);

  const handleSave = () => {
    if (!note) return;
    
    onSave({
      ...note,
      title: title.trim() || '无标题笔记',
      content: content.trim(),
      tags,
      updatedAt: Date.now(),
      lastEditDevice: currentDevice,
    });
    onClose();
  };

  const handleAddTag = () => {
    if (newTag.trim() && !tags.includes(newTag.trim())) {
      setTags([...tags, newTag.trim()]);
      setNewTag('');
    }
  };

  const handleRemoveTag = (tag: string) => {
    setTags(tags.filter((t) => t !== tag));
  };

  if (!isOpen || !note) return null;

  return (
    <div className="fixed inset-0 bg-background z-50 flex flex-col">
      {/* 头部工具栏 */}
      <div className="flex items-center justify-between p-4 border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <Button variant="ghost" size="icon" onClick={onClose}>
          <X className="size-5" />
        </Button>
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground">
            自动保存
          </span>
          <Button onClick={handleSave}>
            <Check className="size-4 mr-2" />
            完成
          </Button>
        </div>
      </div>

      {/* 编辑区域 */}
      <div className="flex-1 overflow-y-auto">
        <div className="max-w-4xl mx-auto p-4 space-y-4">
          {/* 标题 */}
          <Input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="笔记标题"
            className="text-2xl font-bold border-0 px-0 h-auto focus-visible:ring-0"
          />

          {/* 标签 */}
          <div className="flex flex-wrap gap-2 items-center">
            {tags.map((tag) => (
              <Badge
                key={tag}
                variant="secondary"
                className="cursor-pointer hover:bg-destructive hover:text-destructive-foreground transition-colors"
                onClick={() => handleRemoveTag(tag)}
              >
                {tag} ×
              </Badge>
            ))}
            {showTagInput ? (
              <div className="flex gap-2">
                <Input
                  value={newTag}
                  onChange={(e) => setNewTag(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      handleAddTag();
                    } else if (e.key === 'Escape') {
                      setShowTagInput(false);
                      setNewTag('');
                    }
                  }}
                  placeholder="输入标签名"
                  className="h-8 w-32"
                  autoFocus
                />
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => {
                    handleAddTag();
                    setShowTagInput(false);
                  }}
                >
                  添加
                </Button>
              </div>
            ) : (
              <Button
                size="sm"
                variant="outline"
                onClick={() => setShowTagInput(true)}
                className="h-7"
              >
                <Tag className="size-3 mr-1" />
                添加标签
              </Button>
            )}
          </div>

          {/* 内容 */}
          <Textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            placeholder="开始写笔记..."
            className="min-h-[60vh] border-0 px-0 text-base resize-none focus-visible:ring-0"
          />

          {/* 元数据 */}
          <div className="text-sm text-muted-foreground py-4 border-t">
            <p>创建时间: {new Date(note.createdAt).toLocaleString('zh-CN')}</p>
            <p>更新时间: {new Date(note.updatedAt).toLocaleString('zh-CN')}</p>
            {note.lastEditDevice && (
              <p>最后编辑设备: {note.lastEditDevice}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
