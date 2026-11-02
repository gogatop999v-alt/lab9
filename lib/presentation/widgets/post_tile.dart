import 'package:flutter/material.dart';

import '../../data/models/post.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text('${post.id}')),
      title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.body.replaceAll('\n', ' '),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [
            Text('Автор #${post.userId}',
                style: Theme.of(context).textTheme.labelSmall),
            if (post.isLocal)
              const Chip(
                label: Text('создан локально'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
          ]),
        ],
      ),
    );
  }
}
