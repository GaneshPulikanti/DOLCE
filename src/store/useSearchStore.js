import { create } from 'zustand';

export const useSearchStore = create((set) => ({
  activeTab: 'home', // 'home' | 'search' | 'library' | 'profile'
  searchQuery: '',
  filterCategory: 'all', // 'all' | 'songs' | 'videos' | 'artists'
  setActiveTab: (tab) => set({ activeTab: tab }),
  setSearchQuery: (query) => set({ searchQuery: query }),
  setFilterCategory: (category) => set({ filterCategory: category }),
}));
