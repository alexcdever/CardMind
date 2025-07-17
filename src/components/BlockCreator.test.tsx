import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';
import { BlockCreator } from './BlockCreator';
import { useBlockManager } from '../stores/blockManager';

// 修复类型声明
declare global {
  namespace jest {
    interface Matchers<R> {
      toBeInTheDocument(): R;
      toHaveValue(value: string): R;
    }
  }
}

// Mock the useBlockManager hook
jest.mock('../stores/blockManager');

const mockUseBlockManager = useBlockManager as jest.MockedFunction<typeof useBlockManager>;

describe('BlockCreator', () => {
  beforeEach(() => {
    mockUseBlockManager.mockReturnValue({
      openBlockId: 'test-parent',
      updateBlock: jest.fn()
    } as any);
  });

  it('should render the component', () => {
    render(<BlockCreator />);
    expect(screen.getByPlaceholderText('输入块标题')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '创建' })).toBeInTheDocument();
  });

  it('should update title when input changes', () => {
    render(<BlockCreator />);
    const input = screen.getByPlaceholderText('输入块标题');
    fireEvent.change(input, { target: { value: '测试块' } });
    expect(input).toHaveValue('测试块');
  });

  it('should call updateBlock when form is submitted', () => {
    const mockUpdateBlock = jest.fn();
    mockUseBlockManager.mockReturnValue({
      openBlockId: 'test-parent',
      updateBlock: mockUpdateBlock
    } as any);

    render(<BlockCreator />);
    const input = screen.getByPlaceholderText('输入块标题');
    const button = screen.getByRole('button', { name: '创建' });

    fireEvent.change(input, { target: { value: '测试块' } });
    fireEvent.click(button);

    expect(mockUpdateBlock).toHaveBeenCalled();
    const createdBlock = mockUpdateBlock.mock.calls[0][0];
    expect(createdBlock.properties.title).toBe('测试块');
    expect(createdBlock.parentId).toBe('test-parent');
  });

  it('should not call updateBlock when title is empty', () => {
    const mockUpdateBlock = jest.fn();
    mockUseBlockManager.mockReturnValue({
      openBlockId: 'test-parent',
      updateBlock: mockUpdateBlock
    } as any);

    render(<BlockCreator />);
    const button = screen.getByRole('button', { name: '创建' });
    fireEvent.click(button);
    expect(mockUpdateBlock).not.toHaveBeenCalled();
  });
});
