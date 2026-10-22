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
        position: GraphPoint3(0, -3.5, 0),
      ),
    ];
    final edges = <QurraGraphEdge>[];
    // Layout follows transmission, not a narrator's city: his own city stays
    // metadata, without pulling him across the graph away from his reader.
    double readerX(ReaderBiography b) => readerBiographies.indexOf(b) * 4.8;

    for (final c in RecitationCity.values.where(cities.contains)) {
      nodes.add(
        QurraGraphNode(
          id: 'city-${c.name}',
          label: c.nameAr,
          kind: QurraNodeKind.city,
          city: c,
          position: GraphPoint3(c.index * 4.8, -2.5, 0),
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
          position: GraphPoint3(readerX(b), -.85, .35),
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
            position: GraphPoint3(
              readerX(b) + (b.narrators.indexOf(n) == 0 ? 1.25 : -1.25),
              .95,
              -.2,
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
