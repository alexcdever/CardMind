import { ipcMain, app } from 'electron';
import { 
  initializeDatabase,
  createTag,
  getAllTags,
  addCard,
  updateCard,
  deleteCard,
  getAllCards,
  searchCards,
  getCardById,
  resetDatabase
} from '@cardmind/core/database';

// Initialize database when app starts
initializeDatabase(app.getPath('userData')).catch(console.error);

// IPC handlers
ipcMain.handle('tag:create', async (_, name) => {
  console.log('Main: Creating tag:', name);
  try {
    const tag = await createTag(name);
    return { success: true, data: tag };
  } catch (error) {
    console.error('Error creating tag:', error);
    return { success: false, error: 'Failed to create tag' };
  }
});

ipcMain.handle('tag:getAll', async () => {
  try {
    const tags = await getAllTags();
    return { success: true, data: tags };
  } catch (error) {
    console.error('Error getting tags:', error);
    return { success: false, error: 'Failed to get tags' };
  }
});

ipcMain.handle('card:add', async (_, { title, content, tags }) => {
  try {
    const card = await addCard({ title, content, tags });
    return { success: true, data: card };
  } catch (error) {
    console.error('Error adding card:', error);
    return { success: false, error: 'Failed to add card' };
  }
});

ipcMain.handle('card:update', async (_, { id, title, content, tags }) => {
  try {
    const card = await updateCard(id, { title, content, tags });
    return { success: true, data: card };
  } catch (error) {
    console.error('Error updating card:', error);
    return { success: false, error: 'Failed to update card' };
  }
});

ipcMain.handle('card:delete', async (_, id) => {
  try {
    await deleteCard(id);
    return { success: true };
  } catch (error) {
    console.error('Error deleting card:', error);
    return { success: false, error: 'Failed to delete card' };
  }
});

ipcMain.handle('card:getAll', async () => {
  try {
    const cards = await getAllCards();
    return { success: true, data: cards };
  } catch (error) {
    console.error('Error getting cards:', error);
    return { success: false, error: 'Failed to get cards' };
  }
});

ipcMain.handle('card:search', async (_, query) => {
  try {
    const cards = await searchCards(query);
    return { success: true, data: cards };
  } catch (error) {
    console.error('Error searching cards:', error);
    return { success: false, error: 'Failed to search cards' };
  }
});

ipcMain.handle('card:getById', async (_, id) => {
  try {
    const card = await getCardById(id);
    return { success: true, data: card };
  } catch (error) {
    console.error('Error getting card:', error);
    return { success: false, error: 'Failed to get card' };
  }
});

ipcMain.handle('database:reset', async () => {
  console.log('Main: Resetting database');
  try {
    const result = await resetDatabase();
    console.log('Main: Database reset result:', result);
    return result;
  } catch (error) {
    console.error('Failed to reset database:', error);
    throw error;
  }
});
