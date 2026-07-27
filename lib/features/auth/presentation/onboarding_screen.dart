import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/widgets/scenic_background.dart';
import '../data/models/user_preference_profile.dart';
import '../providers/personalization_provider.dart';
import '../../youtube/providers/youtube_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtistSuggestion {
  final String name;
  final String? coverUrl;
  const ArtistSuggestion({required this.name, this.coverUrl});
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Selections state
  final List<String> _selectedLanguages = [];
  final List<String> _selectedArtists = [];
  final List<String> _selectedGenres = [];

  late final List<ArtistSuggestion> _suggestedArtists;

  // Options lists
  final List<String> _languages = [
    'Telugu',
    'Hindi',
    'English',
    'Tamil',
    'Malayalam',
    'Kannada',
    'Punjabi',
  ];

  static const List<String> _initialArtists = [
    'Anirudh Ravichander',
    'Arijit Singh',
    'Sid Sriram',
    'A.R. Rahman',
    'Devi Sri Prasad (DSP)',
    'The Weeknd',
    'Ed Sheeran',
    'BTS',
    'Taylor Swift',
    'Shreya Ghoshal',
    'Harris Jayaraj',
    'Yuvan Shankar Raja',
    'S.P. Balasubrahmanyam',
    'K.S. Chithra',
    'Sidhu Moose Wala',
    'Diljit Dosanjh',
    'Pritam',
    'Badshah',
    'Billie Eilish',
    'Dua Lipa',
    'Drake',
    'Justin Bieber',
    'Alan Walker',
    'Coldplay',
  ];

  static const Map<String, List<String>> _relatedArtistsMap = {
    'Devi Sri Prasad (DSP)': [
      'Thaman S',
      'M.M. Keeravani',
      'Harris Jayaraj',
      'Anirudh Ravichander',
      'A.R. Rahman',
      'Mani Sharma',
      'Sid Sriram',
      'Karthik',
    ],
    'Anirudh Ravichander': [
      'Devi Sri Prasad (DSP)',
      'Harris Jayaraj',
      'Yuvan Shankar Raja',
      'G.V. Prakash Kumar',
      'Sid Sriram',
      'Santhosh Narayanan',
      'Thaman S',
      'A.R. Rahman',
    ],
    'Sid Sriram': [
      'Anirudh Ravichander',
      'A.R. Rahman',
      'Karthik',
      'Hariharan',
      'Chinmayi Sripaada',
      'Shreya Ghoshal',
      'Pradeep Kumar',
    ],
    'A.R. Rahman': [
      'Harris Jayaraj',
      'Yuvan Shankar Raja',
      'Devi Sri Prasad (DSP)',
      'M.M. Keeravani',
      'Ilaiyaraaja',
      'Amit Trivedi',
      'S.P. Balasubrahmanyam',
    ],
    'Harris Jayaraj': [
      'Yuvan Shankar Raja',
      'Anirudh Ravichander',
      'A.R. Rahman',
      'G.V. Prakash Kumar',
      'Karthik',
      'Bombay Jayashri',
    ],
    'Yuvan Shankar Raja': [
      'Anirudh Ravichander',
      'Harris Jayaraj',
      'G.V. Prakash Kumar',
      'Ilaiyaraaja',
      'Santhosh Narayanan',
    ],
    'S.P. Balasubrahmanyam': [
      'K.S. Chithra',
      'Ilaiyaraaja',
      'P. Susheela',
      'Yesudas',
      'Hariharan',
      'S. Janaki',
    ],
    'K.S. Chithra': [
      'S.P. Balasubrahmanyam',
      'S. Janaki',
      'P. Susheela',
      'Yesudas',
      'Shreya Ghoshal',
    ],
    'Arijit Singh': [
      'Jubin Nautiyal',
      'Atif Aslam',
      'Armaan Malik',
      'Pritam',
      'Neha Kakkar',
      'Shreya Ghoshal',
      'Mithoon',
      'Ankit Tiwari',
    ],
    'Shreya Ghoshal': [
      'Arijit Singh',
      'Sunidhi Chauhan',
      'Alka Yagnik',
      'K.S. Chithra',
      'Sonu Nigam',
    ],
    'Pritam': [
      'Arijit Singh',
      'Vishal-Shekhar',
      'Amit Trivedi',
      'Sachin-Jigar',
      'Badshah',
      'A.R. Rahman',
    ],
    'Badshah': [
      'Raftaar',
      'Yo Yo Honey Singh',
      'Divine',
      'Diljit Dosanjh',
      'Guru Randhawa',
      'Hardy Sandhu',
    ],
    'Diljit Dosanjh': [
      'Sidhu Moose Wala',
      'AP Dhillon',
      'Guru Randhawa',
      'Amrinder Gill',
      'Badshah',
      'Karan Aujla',
    ],
    'Sidhu Moose Wala': [
      'Karan Aujla',
      'Amrit Maan',
      'Diljit Dosanjh',
      'AP Dhillon',
      'Shubh',
    ],
    'The Weeknd': [
      'Dua Lipa',
      'Post Malone',
      'Drake',
      'Travis Scott',
      'Justin Bieber',
      'Taylor Swift',
      'Bruno Mars',
    ],
    'Ed Sheeran': [
      'Taylor Swift',
      'Shawn Mendes',
      'Coldplay',
      'Justin Bieber',
      'One Direction',
      'Adele',
      'Sam Smith',
    ],
    'Taylor Swift': [
      'Ed Sheeran',
      'Selena Gomez',
      'Olivia Rodrigo',
      'Billie Eilish',
      'Lana Del Rey',
      'Sabrina Carpenter',
    ],
    'BTS': [
      'BLACKPINK',
      'EXO',
      'TXT',
      'NewJeans',
      'Stray Kids',
      'Jungkook',
      'Jimi',
    ],
    'Billie Eilish': [
      'Olivia Rodrigo',
      'Lana Del Rey',
      'Taylor Swift',
      'Finneas',
      'Lorde',
      'Halsey',
    ],
    'Dua Lipa': [
      'The Weeknd',
      'Miley Cyrus',
      'Ariana Grande',
      'Rita Ora',
      'Bebe Rexha',
      'Katy Perry',
    ],
    'Drake': [
      'Travis Scott',
      'Kendrick Lamar',
      'Future',
      'Kanye West',
      'Lil Baby',
      'J. Cole',
      'The Weeknd',
    ],
    'Justin Bieber': [
      'Shawn Mendes',
      'Justin Timberlake',
      'Selena Gomez',
      'Zayn',
      'Charlie Puth',
    ],
    'Alan Walker': [
      'Martin Garrix',
      'Marshmello',
      'The Chainsmokers',
      'David Guetta',
      'Avicii',
      'Kygo',
    ],
    'Coldplay': [
      'OneRepublic',
      'Imagine Dragons',
      'Maroon 5',
      'U2',
      'Keane',
      'Ed Sheeran',
    ],
  };

  static const Map<String, String> _artistCovers = {
    "Anirudh Ravichander": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w120-h120-p-l90-rj",
    "Arijit Singh": "https://lh3.googleusercontent.com/W_yOqnKSDYyeVOY_AsXhuAtb6rW3vCL3GtJ9DA1GxWOrJfyeSOqzvTv_TkFHijdkVPXWutASBlRFPg=w120-h120-p-l90-rj",
    "Sid Sriram": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w120-h120-p-l90-rj",
    "A.R. Rahman": "https://yt3.googleusercontent.com/vHMOuDn8gr3SW9Pm8yFgmtYzM5kj4ayng5HKRjW0OyjG9mPK923XMVtTZTt4NUG_1aemWNLSQ27zjtA=w120-h120-l90-rj",
    "Devi Sri Prasad (DSP)": "https://yt3.googleusercontent.com/Jn3s6U5foBczx3HoJuiVN6euF7QRB1b8rsp3lecxZ7EwumQ-27E_iR2uu8fJV0H6cctb74s5nut_dhM=w120-h120-p-l90-rj",
    "The Weeknd": "https://lh3.googleusercontent.com/U-SAmNOu4TynE818gLCfKsuHZ0U5YNEtO9mrjSI9WCCKERs98LzrCal5kajBBTQNwdcisoB2Bn-pHp4=w120-h120-p-l90-rj",
    "Ed Sheeran": "https://lh3.googleusercontent.com/jQoBIAS6JjFGpcqQY1M_Mh3AasOvFENCdVRxkgax1a0K6qiq7AgE3MbJ6Jtt-Jndcarvoawmrg66KTny=w120-h120-p-l90-rj",
    "BTS": "https://lh3.googleusercontent.com/8rsLpP6VJjt-yTN8ZG5rY-qt2aCC-IYMWmVkk7qa8c5vrjO6zetKSgwO2QknHI3FtWl6Zannp2VsQ5o=w120-h120-l90-rj",
    "Taylor Swift": "https://yt3.googleusercontent.com/RCpTA6EXJQyjVFDosWOKa2SMmqkua_lA9mHPDWWciLwgqpZLz-k8rXWRF_367trrQ7up9BUwCbk6kRk=w120-h120-p-l90-rj",
    "Shreya Ghoshal": "https://yt3.ggpht.com/PgINZNe0qVxgMSXKG5vF82bNN4WCC12zgWsz9I7OLs4CLF9Cn0Vxq7Xc1ToupnzXrCv0nKfe3VM=w120-c-h120-k-c0x00ffffff-no-l90-rj",
    "Harris Jayaraj": "https://yt3.googleusercontent.com/WL9RZw5FixFw1o9En00D9gdXXMwnTs4E2DqvQ18E4DvzEl1MY_zGwIP0AjJ8o2zKe0IOOMwggK_Jr59Xsw=w120-h120-l90-rj",
    "Yuvan Shankar Raja": "https://lh3.googleusercontent.com/-IRVL5B0n7-V9Gh9XZvQG161HYqkH_SNSHfJwWYeIcVVh35sMq9-jHTk1FCeAmeUHSdEq7UMpoVzUPw=w120-h120-p-l90-rj",
    "S.P. Balasubrahmanyam": "https://yt3.googleusercontent.com/i-PUJfHy7H3_s1AUBWUaulTzhclF5MobqSIw_3nM3a2-kfCGsY_67K-dEOW7baAiBdfHvSOuHVjR_g=w120-h120-p-l90-rj",
    "K.S. Chithra": "https://yt3.googleusercontent.com/cFho6QFr9dAAQ7bspBLLi6jkuASqcgmFpgC4s3mnuSZkrUnGU9Zj6EZS5AlbKNv0gVFdw3CEVEGKaQ=w120-h120-p-l90-rj",
    "Sidhu Moose Wala": "https://yt3.ggpht.com/ytc/AIdro_kiQJ0Hhp0O-tdaY1dy81-gSNujjccUlWstnpFr686ZlMk=w120-h120-l90-rj",
    "Diljit Dosanjh": "https://yt3.googleusercontent.com/7EYXXMXY594V8y4sZT2aawmdKgDAGTu5jNm9C-HpR3jY9cZJ0NMxS__nZKBdWZ1PUpJPjc2BAA=w120-h120-l90-rj",
    "Pritam": "https://yt3.googleusercontent.com/sjGMYJQ1J3FZEIBsMYUztMjjYOM4-NJ24CjmIHqxTWCxAM1YgjL-d_17u7_PRhTouOwwAjbu-2x5S6I=w120-h120-p-l90-rj",
    "Badshah": "https://lh3.googleusercontent.com/bbR8znm7CX07mCGQH-M484ckFRaKkSmTjwrwuFZxQUBy7Uc5gQcintkpqDXCuSX0DdLLg2aPskZhC2s=w120-h120-p-l90-rj",
    "Billie Eilish": "https://lh3.googleusercontent.com/tQC4rOL6xz6FhmFr0ggQExxyGbYSOsyveXVSnPBh2WjEyIzQ9pMHablLJ-0GlMBrLBlBrbWQGmzrV6KN=w120-h120-p-l90-rj",
    "Dua Lipa": "https://lh3.googleusercontent.com/aFx8s1fTuelgxONGbezmTG0EKR8r82uB5H-Q6ZJtssyCWLJWF8GfZNr4tHo84sXdFCPBKrA4R6zXOss=w120-h120-p-l90-rj",
    "Drake": "https://yt3.googleusercontent.com/MxNjcRJ-uK4Xvx7u90IhEFLQM8x9LIGTA9VCKHq5U4Wn2jOgiWaMtg-qz329SIzqnCyhdCCB3MpdAGs=w120-h120-p-l90-rj",
    "Justin Bieber": "https://lh3.googleusercontent.com/4ULlRiFBFglNemZJyKn6_e2-iOIdJEbgBgq_79RQclndG6pge0yGgS2k2On6E1FkCJzenyHkHRzkvjFp=w120-h120-p-l90-rj",
    "Alan Walker": "https://yt3.googleusercontent.com/1-Ipiq-y8WyAcWn88nuxwTHaaBWMg8VkCBuP3puDCec-neD3v-7SqoBRzmmBKmA-lir_Ie70yw9EKHk=w120-h120-p-l90-rj",
    "Coldplay": "https://lh3.googleusercontent.com/IOKuXtp8PCQ_Fc-vaRKm3sKIXBxFV51gZheLTH5br-YGnWHFQf_Jywcuk7wbprYRoEbQyS_XZY6-nMJX=w120-h120-p-l90-rj"
  };

  @override
  void initState() {
    super.initState();
    _suggestedArtists = _initialArtists.map((name) {
      return ArtistSuggestion(name: name, coverUrl: _artistCovers[name]);
    }).toList();
  }

  void _onArtistTapped(ArtistSuggestion suggestion) async {
    final artist = suggestion.name;
    final isSelected = _selectedArtists.contains(artist);
    setState(() {
      if (isSelected) {
        _selectedArtists.remove(artist);
      } else {
        _selectedArtists.add(artist);
      }
    });

    if (!isSelected) {
      // User just selected this artist! Load and suggest related artists.
      final relatedNames = _relatedArtistsMap[artist] ?? [];
      
      // Dynamic fallback via YT Music search
      List<ArtistSuggestion> apiRelated = [];
      try {
        final repo = await ref.read(ytMusicRepositoryProvider.future);
        final searchResults = await repo.searchArtists(artist);
        if (searchResults.isNotEmpty) {
          final bestMatch = searchResults.first;
          final artistId = bestMatch['id'];
          if (artistId != null) {
            final songs = await repo.getArtistSongs(artistId);
            for (final song in songs) {
              if (song.artistName.trim().isNotEmpty && song.artistName != artist) {
                if (!apiRelated.any((e) => e.name == song.artistName)) {
                  final artistResults = await repo.searchArtists(song.artistName);
                  String? thumbnail;
                  if (artistResults.isNotEmpty) {
                    thumbnail = artistResults.first['thumbnail'];
                  }
                  apiRelated.add(ArtistSuggestion(
                    name: song.artistName,
                    coverUrl: thumbnail ?? _artistCovers[song.artistName],
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ [Onboarding] Failed to fetch dynamic related artists: $e');
      }

      setState(() {
        final newSuggestions = <ArtistSuggestion>[];
        for (final rName in relatedNames) {
          if (!_selectedArtists.contains(rName) && !_suggestedArtists.any((e) => e.name == rName)) {
            newSuggestions.add(ArtistSuggestion(
              name: rName,
              coverUrl: _artistCovers[rName],
            ));
          }
        }
        for (final suggestion in apiRelated) {
          if (!_selectedArtists.contains(suggestion.name) &&
              !_suggestedArtists.any((e) => e.name == suggestion.name) &&
              !newSuggestions.any((e) => e.name == suggestion.name)) {
            newSuggestions.add(suggestion);
          }
        }
        
        // Insert new suggestions at the beginning
        _suggestedArtists.insertAll(0, newSuggestions);
      });
    }
  }

  final List<String> _genres = [
    'Melody',
    'Romantic',
    'Mass',
    'Lo-Fi',
    'EDM',
    'Hip-Hop',
    'Devotional',
    'Workout',
    'Chill',
    'Party',
  ];

  // Validation helpers
  bool get _isLanguageValid => _selectedLanguages.isNotEmpty;
  bool get _isArtistValid => _selectedArtists.length >= 5;
  bool get _isGenreValid => _selectedGenres.length >= 3;

  bool get _isCurrentStepValid {
    if (_currentStep == 0) return _isLanguageValid;
    if (_currentStep == 1) return _isArtistValid;
    if (_currentStep == 2) return _isGenreValid;
    return false;
  }

  void _nextStep() {
    if (!_isCurrentStepValid) return;
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _finishOnboarding() {
    final profile = UserPreferenceProfile(
      languages: _selectedLanguages,
      artists: _selectedArtists,
      genres: _selectedGenres,
      createdAt: DateTime.now(),
    );
    ref.read(userPreferenceProfileProvider.notifier).savePreferences(profile);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return ScenicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Indicator & Skip/Back Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      GestureDetector(
                        onTap: _previousStep,
                        child: Text(
                          'Back',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 32),
                    
                    Text(
                      'Step ${_currentStep + 1} of 3',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(width: 32), // Spacer to balance
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      width: MediaQuery.of(context).size.width * ((_currentStep + 1) / 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Title Section
                _buildHeader(),
                const SizedBox(height: 24),

                // Form Page View
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() {
                        _currentStep = page;
                      });
                    },
                    children: [
                      _buildLanguagePage(),
                      _buildArtistPage(),
                      _buildGenrePage(),
                    ],
                  ),
                ),

                // Bottom Action Button
                const SizedBox(height: 16),
                _buildActionButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    String subtitle = '';
    if (_currentStep == 0) {
      title = 'Select Languages';
      subtitle = 'Choose at least 1 language to start receiving localized songs.';
    } else if (_currentStep == 1) {
      title = 'Favorite Artists';
      subtitle = 'Select at least 5 artists you listen to frequently.';
    } else if (_currentStep == 2) {
      title = 'Genres & Moods';
      subtitle = 'Pick at least 3 genres or moods matching your taste.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ).animate(key: ValueKey('title_$_currentStep')).fadeIn(duration: 400.ms).slideY(begin: 0.1),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.45),
            height: 1.4,
          ),
        ).animate(key: ValueKey('sub_$_currentStep')).fadeIn(duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }

  Widget _buildLanguagePage() {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        children: _languages.map((lang) {
          final isSelected = _selectedLanguages.contains(lang);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedLanguages.remove(lang);
                } else {
                  _selectedLanguages.add(lang);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Text(
                lang,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        }).toList(),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildArtistPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected count helper text
          Text(
            'Selected: ${_selectedArtists.length} of 5 required',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _selectedArtists.length >= 5 ? Colors.greenAccent : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: _suggestedArtists.length,
            itemBuilder: (context, index) {
              final artist = _suggestedArtists[index];
              final isSelected = _selectedArtists.contains(artist.name);
              final initials = artist.name.split(' ').map((e) => e.isEmpty ? '' : e[0]).join().toUpperCase();
              final displayInitials = initials.substring(0, initials.length > 2 ? 2 : initials.length);

              return GestureDetector(
                onTap: () => _onArtistTapped(artist),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.greenAccent : Colors.white.withValues(alpha: 0.1),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.greenAccent.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : [],
                              ),
                              child: ClipOval(
                                child: artist.coverUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: artist.coverUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => _buildInitialsAvatar(displayInitials, isSelected),
                                      )
                                    : _buildInitialsAvatar(displayInitials, isSelected),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artist.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildInitialsAvatar(String initials, bool isSelected) {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.greenAccent : Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildGenrePage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected count helper text
          Text(
            'Selected: ${_selectedGenres.length} of 3 required',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _selectedGenres.length >= 3 ? Colors.greenAccent : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 14,
            children: _genres.map((genre) {
              final isSelected = _selectedGenres.contains(genre);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedGenres.remove(genre);
                    } else {
                      _selectedGenres.add(genre);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildActionButton() {
    final isValid = _isCurrentStepValid;

    return Center(
      child: GestureDetector(
        onTap: _nextStep,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: isValid ? Colors.white : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            boxShadow: isValid
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              _currentStep < 2 ? 'Continue' : 'Finish Onboarding',
              style: TextStyle(
                fontFamily: 'Inter',
                color: isValid ? Colors.black : Colors.white.withValues(alpha: 0.35),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
