import { create } from 'zustand';
import { Card, CreateCardPayload, UpdateCardPayload } from '../types/card';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:9000/api/v1';

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
      const response = await fetch(`${API_BASE_URL}/cards`, {
        headers: {
          'Accept': 'application/json',
        },
      });
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

  addCard: async (card: CreateCardPayload) => {
    try {
      set({ loading: true });
      const response = await fetch(`${API_BASE_URL}/cards`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(card),
      });
      if (!response.ok) {
        throw new Error(`Failed to add card: ${response.status} ${response.statusText}`);
      }
      const newCard = await response.json();
      set(state => ({ cards: [...state.cards, newCard] }));
      return newCard;
    } catch (error) {
      console.error('Failed to add card:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  updateCard: async (id: number, card: UpdateCardPayload) => {
    try {
      set({ loading: true });
      const response = await fetch(`${API_BASE_URL}/cards/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(card),
      });
      if (!response.ok) {
        throw new Error(`Failed to update card: ${response.status} ${response.statusText}`);
      }
      const updatedCard = await response.json();
      set(state => ({
        cards: state.cards.map(c => c.id === id ? updatedCard : c),
      }));
      return updatedCard;
    } catch (error) {
      console.error('Failed to update card:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  deleteCard: async (id: number) => {
    try {
      set({ loading: true });
      const response = await fetch(`${API_BASE_URL}/cards/${id}`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
        },
      });
      if (!response.ok) {
        throw new Error(`Failed to delete card: ${response.status} ${response.statusText}`);
      }
      set(state => ({
        cards: state.cards.filter(card => card.id !== id),
      }));
    } catch (error) {
      console.error('Failed to delete card:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },
}));