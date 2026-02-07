import 'package:cardmind/models/sort_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_return_display_name_for_each_sort_option', () {
    expect(SortOption.createdAt.displayName, '创建时间');
    expect(SortOption.updatedAt.displayName, '更新时间');
    expect(SortOption.title.displayName, '标题');
  });

  test('it_should_return_icon_for_each_sort_option', () {
    expect(SortOption.createdAt.icon, Icons.schedule);
    expect(SortOption.updatedAt.icon, Icons.update);
    expect(SortOption.title.icon, Icons.title);
  });

  test('it_should_expose_three_sort_options', () {
    expect(SortOption.values.length, 3);
  });

  test('it_should_have_non_empty_display_names', () {
    for (final option in SortOption.values) {
      expect(option.displayName, isNotEmpty);
    }
  });
}
