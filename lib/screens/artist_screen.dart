import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'album_screen.dart';

class ArtistScreen extends StatefulWidget {
  final String artistId;

  const ArtistScreen({super.key, required this.artistId});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  Artist? _artist;
  List<Song> _topSongs = [];
  List<Album> _albums = [];
  bool _isLoading = true;
  bool _isLoadingTopSongs = false;

  @override
  void initState() {
    super.initState();
    _loadArtistDetails();
  }

  Future<void> _loadArtistDetails() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final subsonicService = libraryProvider.subsonicService;

    try {
      Artist? artist;
      List<Song> topSongs = [];
      List<Album> albums = [];

      if (libraryProvider.isLocalOnlyMode) {
        artist = libraryProvider.artists.firstWhere(
          (a) => a.id == widget.artistId,
          orElse: () => Artist(
            id: widget.artistId,
            name: AppLocalizations.of(context)!.unknownArtist,
          ),
        );
        albums = await libraryProvider.getArtistAlbums(widget.artistId);

        topSongs = libraryProvider.cachedAllSongs
            .where((s) => s.artistId == widget.artistId)
            .toList();
      } else {
        final results = await Future.wait<Object>([
          subsonicService.getArtist(widget.artistId),
          subsonicService.getArtistAlbums(widget.artistId),
        ]);
        artist = results[0] as Artist;
        albums = results[1] as List<Album>;
      }

      if (mounted) {
        setState(() {
          _artist = artist;
          _topSongs = topSongs;
          _albums = albums;
          _isLoading = false;
        });
      }
      if (mounted && !libraryProvider.isLocalOnlyMode) {
        _loadTopSongs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTopSongs() async {
    if (!mounted) return;
    if (_isLoadingTopSongs) return;
    setState(() => _isLoadingTopSongs = true);

    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final subsonicService = libraryProvider.subsonicService;

    try {
      var songs = await subsonicService.getArtistTopSongs(widget.artistId);
      if (songs.isEmpty && _albums.isNotEmpty) {
        songs = await _loadAlbumSongsPreview(limit: 50);
      }
      if (!mounted) return;
      setState(() {
        _topSongs = songs;
        _isLoadingTopSongs = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTopSongs = false);
      }
    }
  }

  Future<List<Song>> _loadAlbumSongsPreview({required int limit}) async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final subsonicService = libraryProvider.subsonicService;
    final songs = <Song>[];
    final seenIds = <String>{};

    for (final album in _albums) {
      final albumSongs = await subsonicService.getAlbumSongs(album.id);
      for (final song in albumSongs) {
        if (seenIds.add(song.id)) {
          songs.add(song);
          if (songs.length >= limit) return songs;
        }
      }
    }
    return songs;
  }

  String? get _headerArtwork {
    final artist = _artist;
    if (artist?.artistImageUrl?.isNotEmpty == true) {
      return artist!.artistImageUrl;
    }
    if (artist?.coverArt?.isNotEmpty == true) {
      return artist!.coverArt;
    }
    for (final album in _albums) {
      if (album.coverArt?.isNotEmpty == true) {
        return album.coverArt;
      }
    }
    return null;
  }

  Future<void> _addArtistToQueue() async {
    if (_albums.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final subsonicService = libraryProvider.subsonicService;

    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);

    try {
      final songsToQueue = <Song>[];
      for (final album in _albums) {
        final albumSongs = libraryProvider.isLocalOnlyMode
            ? libraryProvider.cachedAllSongs
                .where((s) => s.albumId == album.id)
                .toList()
            : await subsonicService.getAlbumSongs(album.id);

        songsToQueue.addAll(albumSongs);
      }

      if (songsToQueue.isNotEmpty) {
        playerProvider.addAllToQueue(songsToQueue);
      }

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(loc!.addedArtistToQueue),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(loc!.addedArtistToQueueError),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _playTopSongs({bool shuffle = false}) {
    if (_topSongs.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    var songs = List<Song>.from(_topSongs);
    if (shuffle) {
      songs.shuffle();
    }

    playerProvider.playSong(songs.first, playlist: songs, startIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerArtwork = _headerArtwork;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_artist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(AppLocalizations.of(context)!.artistDataNotFound),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_artist!.name),
              background: headerArtwork != null
                  ? ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.transparent],
                        ).createShader(
                          Rect.fromLTRB(0, 0, rect.width, rect.height),
                        );
                      },
                      blendMode: BlendMode.dstIn,
                      child: AlbumArtwork(
                        coverArt: headerArtwork,
                        size: 200,
                        borderRadius: 0,
                      ),
                    )
                  : Container(
                      color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.mic_fill,
                          size: 64,
                          color: AppTheme.appleMusicRed,
                        ),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.queue_music_rounded),
                tooltip: AppLocalizations.of(context)!.addToQueue,
                onPressed: _albums.isEmpty ? null : () => _addArtistToQueue(),
              ),
            ],
          ),
          if (_topSongs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _PlayButton(
                        icon: CupertinoIcons.play_fill,
                        label: AppLocalizations.of(context)!.play,
                        onTap: () => _playTopSongs(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlayButton(
                        icon: CupertinoIcons.shuffle,
                        label: AppLocalizations.of(context)!.shuffle,
                        onTap: () => _playTopSongs(shuffle: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingTopSongs || _topSongs.isNotEmpty) ...[
                    Text(
                      AppLocalizations.of(context)!.topSongs,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_topSongs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _topSongs.take(5).length,
                        itemBuilder: (context, index) {
                          final song = _topSongs[index];
                          return SongTile(
                            song: song,
                            playlist: _topSongs,
                            index: index,
                            showAlbum: true,
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                  Builder(
                    builder: (context) {
                      // Categorize albums by song count
                      final albums = _albums
                          .where((a) => (a.songCount ?? 0) >= 7)
                          .toList();
                      final eps = _albums.where((a) {
                        final count = a.songCount ?? 0;
                        return count >= 3 && count <= 6;
                      }).toList();
                      final singles = _albums
                          .where((a) => (a.songCount ?? 0) <= 2)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (albums.isNotEmpty) ...[
                            Text(
                              AppLocalizations.of(context)!.sectionAlbums,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: albums.length,
                              itemBuilder: (context, index) {
                                final album = albums[index];
                                return AlbumCard(
                                  album: album,
                                  size: double.infinity,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AlbumScreen(albumId: album.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (eps.isNotEmpty) ...[
                            Text(
                              AppLocalizations.of(context)!.sectionEPs,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: eps.length,
                              itemBuilder: (context, index) {
                                final album = eps[index];
                                return AlbumCard(
                                  album: album,
                                  size: double.infinity,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AlbumScreen(albumId: album.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (singles.isNotEmpty) ...[
                            Text(
                              AppLocalizations.of(context)!.sectionSingles,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: singles.length,
                              itemBuilder: (context, index) {
                                final album = singles[index];
                                return AlbumCard(
                                  album: album,
                                  size: double.infinity,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AlbumScreen(albumId: album.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
