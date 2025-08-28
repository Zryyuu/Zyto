import 'package:flutter/material.dart';
class TodoFilterView<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T item) getPriority;
  final Widget Function(int index, T item) itemBuilder;

  const TodoFilterView({
    super.key,
    required this.items,
    required this.getPriority,
    required this.itemBuilder,
  });

  @override
  State<TodoFilterView<T>> createState() => _TodoFilterScreenState<T>();
}

class _TodoFilterScreenState<T> extends State<TodoFilterView<T>> {
  final Set<String> _selected = {'Tinggi', 'Sedang', 'Rendah'};
  final List<String> _priorities = const ['Tinggi', 'Sedang', 'Rendah'];

  @override
  Widget build(BuildContext context) {
    final filteredEntries = widget.items.asMap().entries
        .where((e) => _selected.contains(widget.getPriority(e.value)))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Tugas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Prioritas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _priorities.map((p) {
              final selected = _selected.contains(p);
              final color = _priorityColor(p);
              return FilterChip(
                label: Text(p),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selected.add(p);
                    } else {
                      _selected.remove(p);
                    }
                  });
                },
                selectedColor: color.withValues(alpha: 0.2),
                checkmarkColor: color,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Hasil', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${filteredEntries.length} tugas', style: TextStyle(color: Theme.of(context).primaryColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredEntries.isEmpty
                ? _emptyState(context)
                : ListView.builder(
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return widget.itemBuilder(entry.key, entry.value);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('Tidak ada tugas untuk filter ini', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Tinggi':
        return Colors.red;
      case 'Sedang':
        return Colors.orange;
      case 'Rendah':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
