import { create } from 'zustand';
import { Card } from '../types/electron';

interface CardStore {
  cards: Card[];
  setCards: (cards: Card[]) => void;
  addCard: (card: Omit<Card, 'id' | 'createdAt' | 'updatedAt'>) => Promise<void>;
  updateCard: (id: number, card: Partial<Omit<Card, 'id' | 'createdAt' | 'updatedAt'>>) => Promise<void>;
  deleteCard: (id: number) => Promise<void>;
}

export const useCardStore = create<CardStore>((set) => ({
  cards: [],
  setCards: (cards: Card[]) => set({ cards }),
  addCard: async (card) => {
    try {
      const newCard = await window.electron.database.addCard(card);
      set((state) => ({ cards: [newCard, ...state.cards] }));
    } catch (error) {
      console.error('Failed to add card:', error);
      throw error;
    }
  },
  updateCard: async (id, card) => {
    try {
      console.log('CardStore: Updating card:', { id, card });
      const response = await window.electron.database.updateCard(id, card);
      if (!response.success) {
        throw new Error(response.error || 'Failed to update card');
      }
      const updatedCard = response.data;
      console.log('CardStore: Card updated successfully:', updatedCard);
      set((state) => ({
        cards: state.cards.map((c) => (c.id === id ? updatedCard : c)),
      }));
      return updatedCard;
    } catch (error) {
      console.error('CardStore: Failed to update card:', error);
      throw error;
    }
  },
  deleteCard: async (id) => {
    try {
      const success = await window.electron.database.deleteCard(id);
      if (success) {
        set((state) => ({
          cards: state.cards.filter((c) => c.id !== id),
        }));
      }
    } catch (error) {
      console.error('Failed to delete card:', error);
      throw error;
    }
  },
}));