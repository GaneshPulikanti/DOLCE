import { searchCatalog } from '../src/services/catalog.js';

async function test() {
  console.log('Testing search for "tanu nenu"...');
  const res1 = await searchCatalog('tanu nenu');
  console.log('--- "tanu nenu" Songs count:', res1.songs.length);
  res1.songs.forEach((s, i) => console.log(` ${i + 1}.`, s.title, '|', s.artistName));

  console.log('\nTesting search for "thanu nenu"...');
  const res2 = await searchCatalog('thanu nenu');
  console.log('--- "thanu nenu" Songs count:', res2.songs.length);
  res2.songs.forEach((s, i) => console.log(` ${i + 1}.`, s.title, '|', s.artistName));
}

test();
