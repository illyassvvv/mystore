class Channel {
  final int id;
  final String name;
  final String number;
  final String logoUrl;
  final String streamUrl;
  final String category;

  const Channel({
    required this.id,
    required this.name,
    required this.number,
    required this.logoUrl,
    required this.streamUrl,
    this.category = 'رياضة',
  });
}

const List<Channel> kChannels = [
  Channel(
    id: 1,
    name: 'beIN Sports 1',
    number: '01',
    logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/9/96/BeIN_Sports_1.svg/200px-BeIN_Sports_1.svg.png',
    streamUrl: 'http://xmrcars.org:8080/bn1hd/mono.m3u8',
  ),
  Channel(
    id: 2,
    name: 'beIN Sports 2',
    number: '02',
    logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/d/db/BeIN_Sports_2.svg/200px-BeIN_Sports_2.svg.png',
    streamUrl: 'http://xmrcars.org:8080/bn2hd/mono.m3u8',
  ),
  Channel(
    id: 3,
    name: 'beIN Sports 3',
    number: '03',
    logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/3/32/BeIN_Sports_3.svg/200px-BeIN_Sports_3.svg.png',
    streamUrl: 'http://xmrcars.org:8080/bn3hd/mono.m3u8',
  ),
  Channel(
    id: 4,
    name: 'beIN Sports 4',
    number: '04',
    logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/0/07/BeIN_Sports_4.svg/200px-BeIN_Sports_4.svg.png',
    streamUrl: 'https://man1ted.com/be4/index.m3u8',
  ),
  Channel(
    id: 5,
    name: 'beIN Sports 5',
    number: '05',
    logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/8/8d/BeIN_Sports_5.svg/200px-BeIN_Sports_5.svg.png',
    streamUrl: 'https://man1ted.com/be5/index.m3u8',
  ),
  Channel(
    id: 6,
    name: 'beIN Sports 6',
    number: '06',
    logoUrl: 'https://upload.wikimedia.org/wikipedia/en/thumb/8/8d/BeIN_Sports_5.svg/200px-BeIN_Sports_5.svg.png',
    streamUrl: 'https://man1ted.com/be6/index.m3u8',
  ),
];
