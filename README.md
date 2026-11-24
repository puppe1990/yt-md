# yt-md

CLI Ruby que puxa a transcrição de um vídeo do YouTube (Innertube ANDROID + `timedtext` json3) e grava markdown.

```bash
ruby yt_md.rb https://www.youtube.com/watch?v=TtOoLanFzGw
ruby yt_md.rb TtOoLanFzGw -o entrevista.md --timestamps
ruby yt_md.rb https://youtu.be/TtOoLanFzGw --lang pt
ruby yt_md.rb TtOoLanFzGw --json3 captions.json3 -o entrevista.md
```

Padrão: idioma `en`, faixa humana se existir, senão ASR. Cabeçalho em português (`Canal`, `Fonte`, `Faixa`, `Duração`). Pula cues `[Music]` / `[Applause]` / `[Laughter]`.

Não usa Network Listener nem AssemblyAI. HTTP fica injetável nos testes.

## Testes

```bash
bundle exec rake test
```

Ruby 3.4+ / 4.x. Runtime é stdlib (`net/http`, `json`, `optparse`). Bundler só para rake, minitest e faker.
