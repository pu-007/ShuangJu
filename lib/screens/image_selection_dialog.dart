import 'dart:io';
import 'package:flutter/material.dart';

class ImageSelectionDialog extends StatefulWidget {
  final List<File> images;

  const ImageSelectionDialog({super.key, required this.images});

  @override
  State<ImageSelectionDialog> createState() => _ImageSelectionDialogState();
}

class _ImageSelectionDialogState extends State<ImageSelectionDialog> {
  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '选择剧照',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (widget.images.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('没有可用的剧照'),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndices.contains(index);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedIndices.remove(index);
                          } else {
                            _selectedIndices.add(index);
                          }
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              widget.images[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Theme.of(context).primaryColor,
                                        width: 3,
                                      )
                                      : null,
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedIndices.length ==
                                widget.images.length) {
                              _selectedIndices.clear();
                            } else {
                              _selectedIndices.clear();
                              _selectedIndices.addAll(
                                List.generate(
                                  widget.images.length,
                                  (index) => index,
                                ),
                              );
                            }
                          });
                        },
                        child: Text(
                          _selectedIndices.length == widget.images.length
                              ? '取消全选'
                              : '全选',
                        ),
                      ),
                      ElevatedButton(
                        onPressed:
                            _selectedIndices.isEmpty
                                ? null
                                : () {
                                  final selectedImages =
                                      _selectedIndices
                                          .map((index) => widget.images[index])
                                          .toList();
                                  Navigator.pop(context, selectedImages);
                                },
                        child: Text(
                          '确定 (${_selectedIndices.length}/${widget.images.length})',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
