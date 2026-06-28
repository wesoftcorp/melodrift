import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../core/theme/tokens.dart';
import '../widgets/search_results_view.dart';
import '../widgets/voice_search_sheet.dart';

@RoutePage()
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _submittedQuery = '';
  List<String> _suggestions = [];
  List<String> _history = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _submittedQuery.isNotEmpty) {
        setState(() => _submittedQuery = '');
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _controller.text.trim();
      if (query.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final repo = ref.read(musicRepositoryProvider);
      final suggestions = await repo.getSearchSuggestions(query);
      setState(() => _suggestions = suggestions);
    });
  }

  Future<void> _loadHistory() async {
    final historyRepo = ref.read(historyRepositoryProvider);
    final history = await historyRepo.getSearchHistory();
    setState(() => _history = history);
  }

  Future<void> _runSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    _controller.text = cleanQuery;
    _focusNode.unfocus();
    setState(() => _submittedQuery = cleanQuery);
    final historyRepo = ref.read(historyRepositoryProvider);
    await historyRepo.addSearchQuery(cleanQuery);
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search songs, albums, artists...',
            hintStyle: AppTextStyles.monoCaption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _submittedQuery = '';
                        _suggestions = [];
                      });
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.mic),
                    onPressed: () async {
                      final result = await showModalBottomSheet<String>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const VoiceSearchSheet(),
                      );
                      if (result != null && result.isNotEmpty) {
                        await _runSearch(result);
                      }
                    },
                  ),
          ),
          onSubmitted: _runSearch,
        ),
      ),
      body: _buildBody(Theme.of(context)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final query = _controller.text.trim();
    if (_submittedQuery.isNotEmpty && !_focusNode.hasFocus) {
      return SearchResultsView(query: _submittedQuery);
    }
    if (_focusNode.hasFocus && query.isNotEmpty) {
      return ListView.builder(
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            leading: const Icon(Icons.search),
            title: Text(suggestion),
            onTap: () => _runSearch(suggestion),
          );
        },
      );
    }
    if (_history.isEmpty) {
      return const Center(child: Text('Search for songs, artists, or albums'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('RECENT SEARCHES', style: AppTextStyles.monoSectionHeader),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(item),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    await ref.read(historyRepositoryProvider).deleteSearchQuery(item);
                    await _loadHistory();
                  },
                ),
                onTap: () => _runSearch(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
