import 'dart:math' as math;

import 'qurra_biographies.dart';

enum QurraNodeKind { root, city, reader, narrator }

enum QurraEdgeKind { classification, transmission, samePerson }

class GraphPoint3 {
  const GraphPoint3(this.x, this.y, this.z);
  final double x, y, z;
}

class QurraGraphNode {
  const QurraGraphNode({
    required this.id,
    required this.label,
    required this.kind,
    required this.position,
    this.city,
    this.reader,
    this.narrator,
  });
  final String id, label;
  final QurraNodeKind kind;
  final GraphPoint3 position;
  final RecitationCity? city;
  final ReaderBiography? reader;
  final NarratorBiography? narrator;
  String get description => switch (kind) {
    QurraNodeKind.root => 'القراءات العشر ورواتها',
    QurraNodeKind.city => '${city!.nameAr}، بلد الإقراء أو الاشتهار',
    QurraNodeKind.reader =>
      '${reader!.fullName}، ${city!.nameAr}، ${reader!.group.nameAr}',
    QurraNodeKind.narrator =>
      '${narrator!.title}، ${narrator!.fullName}، ${city!.nameAr}',
  };
}

typedef QurraGraphEdge = ({String from, String to, QurraEdgeKind kind});

/// Edges distinguish city association, transmission, and shared identity.
/// In particular, a narrator's city is never inherited from his reader.
class QurraGraph {
  QurraGraph._(this.nodes, this.edges);
  final List<QurraGraphNode> nodes;
  final List<QurraGraphEdge> edges;
  int get readerCount =>
      nodes.where((n) => n.kind == QurraNodeKind.reader).length;
  int get narratorCount =>
      nodes.where((n) => n.kind == QurraNodeKind.narrator).length;

  factory QurraGraph.build({
    String query = '',
    RecitationCity? city,
    RecitationGroup? group,
    bool narratorCity = false,
  }) {
    final selected = <(ReaderBiography, List<NarratorBiography>)>[];
    for (final b in readerBiographies) {
      if (group != null && b.group != group) continue;
      if (city != null && !narratorCity && b.city != city) continue;
      final ownMatch = biographyMatches(
        query,
        '${b.qiraa.nameAr} ${b.qiraa.nameEn} ${b.fullName} ${b.city.nameAr} ${b.city.searchAliases} ${b.group.nameAr}',
      );
      final narrators = b.narrators
          .where(
            (n) =>
                (city == null || !narratorCity || n.city == city) &&
                (ownMatch || biographyMatches(query, narratorSearchText(n))),
          )
          .toList();
      if ((city != null && narratorCity || !ownMatch) && narrators.isEmpty) {
        continue;
      }
      selected.add((b, narrators));
    }
    if (selected.isEmpty) return QurraGraph._(const [], const []);
    final cities = {
      for (final (b, ns) in selected) ...[b.city, ...ns.map((n) => n.city)],
    };
    final nodes = <QurraGraphNode>[
      const QurraGraphNode(
        id: 'root',
        label: 'القراءات\nالعشر',
        kind: QurraNodeKind.root,
        position: GraphPoint3(0, 0, 0),
      ),
    ];
    final edges = <QurraGraphEdge>[];
    GraphPoint3 position(
      RecitationCity c,
      double radius,
      int index,
      int count,
    ) {
      final angle =
          -math.pi / 2 +
          c.index * math.pi / 4 +
          (index - (count - 1) / 2) * .19;
      return GraphPoint3(
        math.cos(angle) * radius,
        math.sin(angle) * radius,
        math.sin(c.index * 1.7) * .65 + (index - (count - 1) / 2) * .16,
      );
    }

    for (final c in RecitationCity.values.where(cities.contains)) {
      nodes.add(
        QurraGraphNode(
          id: 'city-${c.name}',
          label: c.nameAr,
          kind: QurraNodeKind.city,
          city: c,
          position: position(c, 1.15, 0, 1),
        ),
      );
      edges.add((
        from: 'root',
        to: 'city-${c.name}',
        kind: QurraEdgeKind.classification,
      ));
    }
    // Stable positions across filters make it possible to retain orientation.
    final allNarrators = [for (final b in readerBiographies) ...b.narrators];
    for (final (b, ns) in selected) {
      final peers = readerBiographies.where((r) => r.city == b.city).toList();
      final id = 'reader-${b.qiraaId}';
      nodes.add(
        QurraGraphNode(
          id: id,
          label: b.qiraa.shortAr,
          kind: QurraNodeKind.reader,
          city: b.city,
          reader: b,
          position: position(b.city, 2, peers.indexOf(b), peers.length),
        ),
      );
      edges.add((
        from: 'city-${b.city.name}',
        to: id,
        kind: QurraEdgeKind.classification,
      ));
      for (final n in ns) {
        final peers = allNarrators.where((r) => r.city == n.city).toList();
        final nid = 'narrator-${n.riwayaId}';
        final ambiguous = n.personId == 'duri' || n.personId == 'khalaf';
        nodes.add(
          QurraGraphNode(
            id: nid,
            label: ambiguous
                ? '${n.riwaya.nameAr}\n${b.qiraa.shortAr}'
                : n.riwaya.nameAr,
            kind: QurraNodeKind.narrator,
            city: n.city,
            reader: b,
            narrator: n,
            position: position(n.city, 2.9, peers.indexOf(n), peers.length),
          ),
        );
        edges.add((from: id, to: nid, kind: QurraEdgeKind.transmission));
        edges.add((
          from: 'city-${n.city.name}',
          to: nid,
          kind: QurraEdgeKind.classification,
        ));
      }
    }
    void shared(String a, String b) {
      if (nodes.any((n) => n.id == a) && nodes.any((n) => n.id == b)) {
        edges.add((from: a, to: b, kind: QurraEdgeKind.samePerson));
      }
    }

    shared('narrator-duri_abuamr', 'narrator-duri_kisai');
    shared('reader-khalaf', 'narrator-khalaf_hamzah');
    return QurraGraph._(List.unmodifiable(nodes), List.unmodifiable(edges));
  }
}
