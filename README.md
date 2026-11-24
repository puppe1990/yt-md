# yt-md

CLI Ruby que puxa a transcrição de um vídeo do YouTube (Innertube ANDROID + `timedtext` json3) e grava markdown.

```bash
ruby yt_md.rb https://www.youtube.com/watch?v=TtOoLanFzGw
ruby yt_md.rb TtOoLanFzGw -o entrevista.md --timestamps
ruby yt_md.rb https://youtu.be/TtOoLanFzGw --lang pt
ruby yt_md.rb TtOoLanFzGw --json3 captions.json3 -o entrevista.md
ruby yt_md.rb https://www.youtube.com/@a16z -o ~/Downloads/a16z-transcripts --sleep 0.4
ruby yt_md.rb @a16z -o ./a16z --limit 10
```

Padrão: idioma `en`, faixa humana se existir, senão ASR. Cabeçalho em português (`Canal`, `Fonte`, `Faixa`, `Duração`). Pula cues `[Music]` / `[Applause]` / `[Laughter]`.

Canal (`@handle` ou `/channel/UCxx`): lista a aba Videos (Innertube WEB + continuations) e grava um `.md` por vídeo no diretório `-o`. Já existente é pulado; vídeo sem legenda também. Shorts ficam fora.

Não usa Network Listener nem AssemblyAI. HTTP fica injetável nos testes.

## Testes

```bash
bundle exec rake test
npm run ci
```

Ruby 3.4+ / 4.x. Runtime é stdlib (`net/http`, `json`, `optparse`). Bundler só para rake, minitest, faker e rubocop. Pre-commit Husky roda lint-staged (Prettier, ESLint, RuboCop) e a suíte.
