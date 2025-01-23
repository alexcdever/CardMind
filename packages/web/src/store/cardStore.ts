import { create } from 'zustand';
import { Card, CreateCardPayload, UpdateCardPayload } from '../types/card';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:9999';

interface CardStore {
  cards: Card[];
  loading: boolean;
  setCards: (cards: Card[]) => void;
  addCard: (card: CreateCardPayload) => Promise<Card>;
  updateCard: (id: number, card: UpdateCardPayload) => Promise<Card>;
  deleteCard: (id: number) => Promise<void>;
  loadCards: () => Promise<void>;
}

export const useCardStore = create<CardStore>((set, get) => ({
  cards: [],
  loading: false,
  setCards: (cards: Card[]) => set({ cards }),
  
  loadCards: async () => {
    try {
      set({ loading: true });
      const response = await fetch(`${API_BASE_URL}/api/cards`);
      if (!response.ok) {
        throw new Error(`Failed to load cards: ${response.status} ${response.statusText}`);
      }
      const cards = await response.json();
      set({ cards });
    } catch (error) {
      console.error('Failed to load cards:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  addCard: async (card) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/cards`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(card),
      });

      if (!response.ok) {
        throw new Error(`Failed to add card: ${response.status} ${response.statusText}`);
      }

      const newCard = await response.json();
      set((state) => ({ cards: [newCard, ...state.cards] }));
      return newCard;
    } catch (error) {
      console.error('Failed to add card:', error);
      throw error;
    }
  },

  updateCard: async (id, card) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/cards/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(card),
      });

      if (!response.ok) {
        throw new Error(`Failed to update card: ${response.status} ${response.statusText}`);
      }

      const updatedCard = await response.json();
      set((state) => ({
        cards: state.cards.map((c) => (c.id === id ? updatedCard : c)),
      }));
      return updatedCard;
    } catch (error) {
      console.error('Failed to update card:', error);
      throw error;
    }
  },

  deleteCard: async (id) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/cards/${id}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        throw new Error(`Failed to delete card: ${response.status} ${response.statusText}`);
      }

      set((state) => ({
        cards: state.cards.filter((c) => c.id !== id),
      }));
    } catch (error) {
      console.error('Failed to delete card:', error);
      throw error;
    }
  },
}));