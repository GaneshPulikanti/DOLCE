import { searchCatalog } from '../src/services/catalog.js';

async function test() {
  try {
    console.log('Testing searchCatalog...');
    const res = await searchCatalog('one nenokkadine');
    console.log('Results count:', res.songs.length);
  } catch (e) {
    console.error('SEARCH CRASHED:', e);
  }
}

test();
