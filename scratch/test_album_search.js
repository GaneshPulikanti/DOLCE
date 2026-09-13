import { searchCatalog } from '../src/services/catalog.js';

async function test() {
  console.log('Testing "one nenokkadine" and "1 Nenokkadine"...');

  for (const q of ['one nenokkadine', '1 Nenokkadine']) {
    console.log(`\n================ Query: "${q}" ================`);
    const res = await searchCatalog(q);
    console.log('Songs count:', res.songs.length);
    res.songs.slice(0, 8).forEach(s => console.log('  Song:', s.title, '|', s.artistName));
    console.log('Albums count:', res.albums.length);
    res.albums.forEach(a => console.log('  Album:', a.title, '|', a.artistName, '| ID:', a.id));
    console.log('Playlists count:', res.playlists.length);
    res.playlists.slice(0, 3).forEach(p => console.log('  Playlist:', p.title, '|', p.author, '| ID:', p.id));
  }
}

test();
