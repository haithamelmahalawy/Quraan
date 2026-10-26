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
        position: GraphPoint3(0, -3.6, 0),
      ),
    ];
    final edges = <QurraGraphEdge>[];
    // A cone around a vertical axis: the cities on an inner ring, the readers
    // on an outer one in their city's sector, each reader's narrators hanging
    // straight below him. Layout follows transmission, not a narrator's city: his own
    // city stays metadata, without pulling him away from his reader. Angles
    // come from all the readers, so positions stay stable across filters.
    final order = [
      for (final c in RecitationCity.values)
        ...readerBiographies.where((b) => b.city == c),
    ];
    double readerAngle(ReaderBiography b) =>
        (order.indexOf(b) + .5) / order.length * math.pi * 2;
    GraphPoint3 at(double angle, double radius, double y) =>
        GraphPoint3(radius * math.sin(angle), y, -radius * math.cos(angle));
    // A city's angle is the mean of its readers' (or else its narrators').
    double cityAngle(RecitationCity c) {
      var sin = 0.0, cos = 0.0;
      for (final b in readerBiographies) {
        final own = b.city == c;
        for (final a in [
          if (own) readerAngle(b),
          if (!readerBiographies.any((r) => r.city == c))
            for (final _ in b.narrators.where((n) => n.city == c))
              readerAngle(b),
        ]) {
          sin += math.sin(a);
          cos += math.cos(a);
        }
      }
      return math.atan2(sin, cos);
    }

    for (final c in RecitationCity.values.where(cities.contains)) {
      nodes.add(
        QurraGraphNode(
          id: 'city-${c.name}',
          label: c.nameAr,
          kind: QurraNodeKind.city,
          city: c,
          // Cities of narrators only sit inside the cone, below the readers.
          position: readerBiographies.any((b) => b.city == c)
              ? at(cityAngle(c), 2.6, -2)
              : at(cityAngle(c), 2.4, 3.6),
        ),
      );
      edges.add((
        from: 'root',
        to: 'city-${c.name}',
        kind: QurraEdgeKind.classification,
      ));
    }
    // Stable positions across filters make it possible to retain orientation.
    for (final (b, ns) in selected) {
      final id = 'reader-${b.qiraaId}';
      nodes.add(
        QurraGraphNode(
          id: id,
          label: b.qiraa.shortAr,
          kind: QurraNodeKind.reader,
          city: b.city,
          reader: b,
          position: at(readerAngle(b), 4.6, 0),
        ),
      );
      edges.add((
        from: 'city-${b.city.name}',
        to: id,
        kind: QurraEdgeKind.classification,
      ));
      for (final n in ns) {
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
            position: at(
              readerAngle(b),
              5,
              b.narrators.indexOf(n) == 0 ? 1.4 : 2.65,
            ),
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
