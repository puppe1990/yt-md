# yt-md

CLI Ruby que puxa a transcrição publicada no YouTube e grava markdown. Um
vídeo vira um arquivo; um canal vira uma pasta com um `.md` por vídeo da aba
Videos.

[![CI](https://github.com/puppe1990/yt-md/actions/workflows/ci.yml/badge.svg)](https://github.com/puppe1990/yt-md/actions/workflows/ci.yml)

Usa as legendas que o YouTube já publica, via Innertube
(`youtubei/v1/player` ANDROID + `timedtext` json3). Runtime é a stdlib
(`net/http`, `json`, `optparse`).

## Instalar

Ruby 3.4 ou 4.x.

```bash
git clone https://github.com/puppe1990/yt-md.git
cd yt-md
ruby yt_md.rb --help
```

`bundle` e `npm` só entram para testes, lint e o pre-commit.

## Um vídeo

Aceita id de 11 caracteres, `watch`, `youtu.be`, Shorts, embed e live.

```bash
ruby yt_md.rb https://www.youtube.com/watch?v=TtOoLanFzGw
ruby yt_md.rb TtOoLanFzGw -o entrevista.md --timestamps
ruby yt_md.rb https://youtu.be/TtOoLanFzGw --lang pt
ruby yt_md.rb TtOoLanFzGw --json3 captions.json3 -o entrevista.md
```

Sem `-o`, o markdown vai para o stdout.

## Um canal

Aceita `@handle`, URL `youtube.com/@handle`, `/channel/UCxx` e o id `UC…`.

```bash
ruby yt_md.rb @a16z -o ./a16z --limit 10
ruby yt_md.rb https://www.youtube.com/@a16z -o ~/Downloads/a16z-transcripts --sleep 0.4
```

Lista a aba Videos (continuations do Innertube WEB), cria o diretório `-o` (ou
o handle, se `-o` faltar) e grava `{videoId}.md`. Arquivo que já existe é
pulado; vídeo sem faixa no `--lang` também, com uma linha `skip` no log.

```
listed 10 videos from a16z
ok 1/10 TtOoLanFzGw
skip 2/10 xxxxxxxxxxxx exists
skip 3/10 yyyyyyyyyyy no captionTracks in player payload
```

Rode de novo no mesmo diretório para continuar de onde parou. `--sleep` pausa
entre um player e o próximo.

## Flags

| Flag              | Padrão          | Efeito                                           |
| ----------------- | --------------- | ------------------------------------------------ |
| `-o`, `--output`  | stdout / handle | Arquivo do vídeo, ou pasta do canal              |
| `--lang LANG`     | `en`            | Idioma da faixa. Prefere humana; senão ASR       |
| `--timestamps`    | off             | Prefixa cada cue com o relógio (`**00:09**`)     |
| `--json3 FILE`    | live            | Usa um timedtext json3 capturado no lugar do GET |
| `--limit N`       | aba inteira     | Para a paginação depois de N vídeos              |
| `--sleep SECONDS` | `0`             | Pausa entre vídeos no dump de canal              |

## Markdown

Cabeçalho em português. Cues `[Music]`, `[Applause]` e `[Laughter]` saem fora.

```markdown
# Why AI Has DHH Working 16-Hour Days

- Canal: a16z
- Fonte: https://www.youtube.com/watch?v=TtOoLanFzGw
- Faixa: en (ASR)
- Duração: 52 min

MacOS and Windows are just unfit for the age of agents. …
```

Com `--timestamps`:

```markdown
**00:00** Mac OS

**00:09** Linux
```

`Faixa: pt` é legenda humana; `Faixa: en (ASR)` é a automática.

## Como puxa

1. Vídeo: `POST /youtubei/v1/player` (cliente ANDROID) → `captionTracks` → GET
   timedtext com `fmt=json3` (o player costuma devolver `srv3`; o CLI troca).
2. Canal: `POST /youtubei/v1/navigation/resolve_url` resolve o `@handle` num
   browse id `UC…`, depois `POST /youtubei/v1/browse` na aba Videos até acabar
   a continuation ou bater o `--limit`.

O HTTP é injetável. Os testes nunca batem no YouTube.

## Testes

```bash
bin/setup               # bundle install + npm ci
bundle exec rake test   # suíte
bin/crap --threshold 10 # CRAP < 10 em lib/
bin/dry --threshold 0.8 # duplicação estrutural em lib/
npm run ci              # Prettier + ESLint + RuboCop + suíte + CRAP + dry
```

Pre-commit Husky roda lint-staged e a suíte.

## Licença

MIT. Veja [LICENSE](LICENSE).
