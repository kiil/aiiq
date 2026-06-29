use http-nu/router *
use http-nu/http *

# JSON-svar med en HTTP-statuskode (til fejl)
def jerr [status: int, msg: string] {
  {error: $msg} | to json
  | metadata set { merge {'http.response': {status: $status, headers: {"Content-Type": "application/json"}}} }
}
# JSON-svar (200) — pipe en value ind
def jok []: any -> any {
  to json | metadata set --content-type "application/json"
}

# Find brugernavn ud fra en session-token (eller null)
def session-user [sid: string] {
  let rows = (.cat -T sessions | where meta.token == $sid)
  if ($rows | is-empty) { null } else { $rows | last | get meta.user }
}
# Admin-brugernavne (komma-sep via env AIIQ_ADMINS, ellers "admin")
def admin-list [] {
  ($env.AIIQ_ADMINS? | default "admin") | split row "," | each {|x| $x | str trim } | where {|x| $x != "" }
}

# AI IQ — en lille quiz der tester folks AI-viden.
# Spørgsmålene lever her i backenden og serveres som JSON til frontend'en.
const QUESTIONS = [
  {
    q: "Hvad står 'GPT' egentlig for?"
    options: [
      "Generative Pre-trained Transformer"
      "General Purpose Translator"
      "Giant Pile of Tensors"
      "Glorificeret Påstands-Tilfældiggenerator"
    ]
    answer: 0
    right: "Korrekt! Selvom 'Giant Pile of Tensors' teknisk set også passer ret godt."
    wrong: "Næ. Det er Generative Pre-trained Transformer — ikke noget med Optimus Prime."
    topic: "Hvad GPT betyder"
    learn: "GPT står for Generative Pre-trained Transformer. 'Pre-trained' = den er først trænet på enorme mængder tekst; 'Generative' = den genererer ny tekst ét token ad gangen; 'Transformer' = den underliggende netværksarkitektur. Tilsammen: en forhåndstrænet tekstgenerator bygget på transformer-arkitekturen."
  }
  {
    q: "Hvad kaldes det, når en sprogmodel selvsikkert finder på rent vrøvl?"
    options: [
      "Hallucination"
      "Kreativ regnskabsføring"
      "Improvisation"
      "En helt almindelig tirsdag"
    ]
    answer: 0
    right: "Ja! En hallucination. Modellen lyver ikke — den er bare meget, meget overbevist."
    wrong: "Det hedder en hallucination. (Selvom 'kreativ regnskabsføring' ramte tæt på.)"
    topic: "Hallucinationer"
    learn: "En hallucination er når en model selvsikkert producerer forkert eller opdigtet information. Den lyver ikke bevidst — den forudsiger blot det mest sandsynlige næste token, og nogle gange bliver det plausibelt vrøvl. Derfor: verificér altid vigtige fakta, og giv gerne modellen kilder at støtte sig til."
  }
  {
    q: "Hvilket firma står bag Claude?"
    options: [
      "Anthropic"
      "OpenAI"
      "Google DeepMind"
      "Skynet Industries A/S"
    ]
    answer: 0
    right: "Præcis — Anthropic. Og nej, vi planlægger ikke at overtage verden. Endnu."
    wrong: "Det er Anthropic. Skynet er heldigvis stadig fiktion."
    topic: "Hvem laver Claude"
    learn: "Claude er udviklet af Anthropic — et AI-firma med fokus på sikkerhed. Til sammenligning: ChatGPT kommer fra OpenAI, og Gemini fra Google DeepMind. At kende aktørerne hjælper med at forstå de forskellige modellers stil og styrker."
  }
  {
    q: "Hvad er en 'token' i en sprogmodel?"
    options: [
      "En stump tekst (ord eller orddel) som modellen behandler"
      "En kryptovaluta du kan tabe penge på"
      "En adgangsnøgle til API'et"
      "Et klippekort til bussen"
    ]
    answer: 0
    right: "Spot on. Modeller tænker i tokens, ikke i hele ord."
    wrong: "En token er en stump tekst. Du betaler ganske vist pr. token — men det er ikke krypto."
    topic: "Tokens"
    learn: "Sprogmodeller læser og skriver i tokens — små stumper tekst, typisk et ord, en orddel eller et tegn. Et langt ord som 'uforudsigelig' kan blive til flere tokens. Vigtigt at vide: både pris og kontekstlængde måles i tokens, ikke i ord."
  }
  {
    q: "Hvad styrer 'temperature' når en model genererer tekst?"
    options: [
      "Hvor tilfældigt og kreativt outputtet bliver"
      "Hvor varm GPU'en bliver"
      "Modellens generelle humør"
      "Antal watt serveren bruger"
    ]
    answer: 0
    right: "Nemlig! Høj temperature = vildere svar. Lav = kedeligt men forudsigeligt."
    wrong: "Temperature styrer kreativiteten/tilfældigheden — ikke GPU'ens kernetemperatur."
    topic: "Temperature"
    learn: "Temperature styrer hvor tilfældigt modellen vælger næste token. Lav temperature (omkring 0) giver fokuserede, forudsigelige og gentagelige svar — godt til fakta og kode. Høj temperature giver mere variation og kreativitet, men også større risiko for vrøvl."
  }
  {
    q: "Hvad er en 'transformer' i AI-sammenhæng?"
    options: [
      "En neural netværksarkitektur baseret på 'attention'"
      "En robot der kan forvandle sig til en lastbil"
      "En komponent i strømforsyningen"
      "Optimus Primes LinkedIn-profil"
    ]
    answer: 0
    right: "Korrekt — 'Attention Is All You Need'. Bogstaveligt talt papirets titel."
    wrong: "Det er en netværksarkitektur (attention). Beklager, ingen Autobots her."
    topic: "Transformer-arkitekturen"
    learn: "Transformeren er den neurale netværksarkitektur bag stort set alle moderne sprogmodeller. Den blev introduceret i 2017-papiret 'Attention Is All You Need'. Dens kerne er en attention-mekanisme, der lader modellen vægte hvilke ord i teksten der er relevante for hinanden — også over lange afstande."
  }
  {
    q: "Hvad gør RAG (Retrieval-Augmented Generation)?"
    options: [
      "Henter relevante dokumenter og giver dem til modellen som kontekst"
      "Får modellen til at svare på rim"
      "Renser træningsdata for bandeord"
      "Det er bare en fancy klud"
    ]
    answer: 0
    right: "Ja! RAG giver modellen 'eksterne noter', så den hallucinerer mindre."
    wrong: "RAG henter dokumenter og fodrer dem til modellen. Ikke en klud, desværre."
    topic: "RAG"
    learn: "Retrieval-Augmented Generation (RAG) henter relevante dokumenter fra en vidensbase og giver dem til modellen som kontekst, før den svarer. Det gør svarene mere opdaterede og faktuelle og reducerer hallucinationer — modellen får så at sige eksterne noter med, i stedet for kun at stole på hukommelsen."
  }
  {
    q: "Hvad betyder 'overfitting'?"
    options: [
      "Modellen lærer træningsdata udenad og fejler på nyt data"
      "Modellen er for stor til din GPU"
      "Der er for mange lag i netværket"
      "Når dit CV overdriver lidt"
    ]
    answer: 0
    right: "Præcis. Modellen blev en stræber der pluggede facit i stedet for at forstå."
    wrong: "Overfitting = den pluggede træningsdata udenad og dumper til eksamen på nyt data."
    topic: "Overfitting"
    learn: "Overfitting er når en model lærer træningsdataene udenad — inklusive tilfældig støj — i stedet for de generelle mønstre. Den klarer sig flot på kendt data, men dårligt på nyt, uset data. Det modvirkes med mere/varieret data, regularisering, og ved at validere på data modellen ikke har set."
  }
  {
    q: "Hvem fik Turing-prisen 2018 som 'the godfathers of deep learning'?"
    options: [
      "Hinton, Bengio & LeCun"
      "Turing, von Neumann & Lovelace"
      "Musk, Altman & Zuckerberg"
      "Mor, far & WiFi-routeren"
    ]
    answer: 0
    right: "Korrekt! Geoffrey Hinton, Yoshua Bengio og Yann LeCun."
    wrong: "Det var Hinton, Bengio & LeCun. WiFi-routeren bidrog dog moralsk."
    topic: "Deep learnings pionerer"
    learn: "Geoffrey Hinton, Yoshua Bengio og Yann LeCun modtog Turing-prisen (datalogiens svar på en Nobelpris) i 2018 for deres gennembrud inden for deep learning. De kaldes ofte 'the godfathers of deep learning' og lagde grunden til de neurale netværk, der driver nutidens AI."
  }
  {
    q: "Hvad er 'fine-tuning'?"
    options: [
      "At træne en forhåndstrænet model videre på specifikke data"
      "At justere GPU-blæserens hastighed"
      "At stemme en guitar"
      "At gøre prompten lidt pænere"
    ]
    answer: 0
    right: "Ja! Du tager en klog model og specialiserer den til din opgave."
    wrong: "Fine-tuning = videre-træning på dine egne data. Guitaren må vente."
    topic: "Fine-tuning"
    learn: "Fine-tuning er at tage en allerede forhåndstrænet model og træne den videre på et mindre, specifikt datasæt — så den bliver bedre til en bestemt opgave, domæne eller stil, uden at man træner fra bunden. Ofte er en god prompt eller RAG dog nok, før man overhovedet behøver fine-tuning."
  }
  {
    q: "Hvad er en 'context window'?"
    options: [
      "Mængden af tekst modellen kan have i 'hukommelsen' på én gang"
      "Et pop op-vindue i browseren"
      "Den tid på dagen modellen er klogest"
      "Udsigten fra serverrummet"
    ]
    answer: 0
    right: "Nemlig — løber du tør for context window, glemmer modellen starten af samtalen."
    wrong: "Det er hvor meget tekst modellen kan rumme ad gangen — ikke et browser-vindue."
    topic: "Context window"
    learn: "Context window er hvor meget tekst (målt i tokens) en model kan holde i 'hukommelsen' på én gang — det dækker både dit input og modellens svar. Løber samtalen ud over vinduet, ryger det tidligste ud og 'glemmes'. Større vinduer kan rumme længere dokumenter og samtaler."
  }
  {
    q: "Hvad er det primære formål med RLHF?"
    options: [
      "At gøre modellens svar mere hjælpsomme og i tråd med menneskers præferencer"
      "At gøre modellen hurtigere"
      "At komprimere modellen så den fylder mindre"
      "At lære den at spille skak"
    ]
    answer: 0
    right: "Korrekt! Reinforcement Learning from Human Feedback = menneskelig finpudsning af opførsel."
    wrong: "RLHF handler om at justere opførsel efter menneskelige præferencer — ikke om fart."
    topic: "RLHF"
    learn: "Reinforcement Learning from Human Feedback (RLHF) finjusterer en models opførsel ud fra menneskers vurderinger af dens svar. Mennesker rangerer outputs, og modellen lærer at foretrække den slags svar. Det er en stor grund til at moderne chatmodeller føles hjælpsomme, høflige og gode til at følge instruktioner."
  }
]

# Slutningens 'rang-titler' bor også her i backenden.
const RANKS = [
  { min: 0,   title: "Stokastisk Papegøje",   emoji: "🦜", desc: "Du gentager AI-buzzwords uden at fortrække en fjer. Træning anbefales." }
  { min: 25,  title: "Prompt-Bonde",           emoji: "🧑‍🌾", desc: "Du dyrker spørgsmål i hånden. Respekt — men der findes traktorer." }
  { min: 45,  title: "Token-Jongløren",        emoji: "🎲", desc: "Du gætter med stil og rammer overraskende ofte rigtigt." }
  { min: 65,  title: "Gradient-Descenderen",   emoji: "📉", desc: "Du bevæger dig støt mod minimum — altså det gode slags minimum." }
  { min: 85,  title: "Prompt-Hviskeren",       emoji: "🧙", desc: "Modellerne adlyder dig. Bjørne i skoven frygter dig. Imponerende." }
  { min: 100, title: "AGI-Overherre",          emoji: "🤖", desc: "Perfekt score. Vi byder vores nye herskere hjerteligt velkommen." }
]

{|req|
  dispatch $req [
    # ---- Spørgsmål ----
    (route {path: "/api/questions"} {|req ctx|
      { questions: $QUESTIONS, ranks: $RANKS } | jok
    })

    # ---- Opret bruger ----
    (route {method: "POST" path: "/api/register"} {|req ctx|
      let body = ($in | from json)
      let u = ($body.user? | default "" | str trim)
      let p = ($body.pass? | default "")
      if ($u | is-empty) or ($p | is-empty) {
        jerr 400 "Brugernavn og kode skal udfyldes"
      } else if ($u | str length) > 24 {
        jerr 400 "Brugernavn må højst være 24 tegn"
      } else if (.cat -T users | where meta.user == $u | is-not-empty) {
        jerr 409 "Brugernavnet er allerede taget"
      } else {
        "" | .append users --meta {user: $u, hash: ($p | hash sha256)}
        let tok = (random uuid)
        "" | .append sessions --meta {token: $tok, user: $u}
        {user: $u} | jok | cookie set "sid" $tok --max-age 2592000
      }
    })

    # ---- Log ind ----
    (route {method: "POST" path: "/api/login"} {|req ctx|
      let body = ($in | from json)
      let u = ($body.user? | default "" | str trim)
      let p = ($body.pass? | default "")
      let rows = (.cat -T users | where meta.user == $u)
      if ($rows | is-empty) or (($rows | last | get meta.hash) != ($p | hash sha256)) {
        jerr 401 "Forkert brugernavn eller kode"
      } else {
        let tok = (random uuid)
        "" | .append sessions --meta {token: $tok, user: $u}
        {user: $u} | jok | cookie set "sid" $tok --max-age 2592000
      }
    })

    # ---- Log ud ----
    (route {method: "POST" path: "/api/logout"} {|req ctx|
      {ok: true} | jok | cookie delete "sid"
    })

    # ---- Hvem er jeg? ----
    (route {path: "/api/me"} {|req ctx|
      let sid = ($req | cookie parse | get sid? | default "")
      let user = (session-user $sid)
      {user: $user, admin: (($user != null) and ($user in (admin-list)))} | jok
    })

    # ---- Indsend score (kræver login) ----
    (route {method: "POST" path: "/api/score"} {|req ctx|
      let body = ($in | from json)
      let sid = ($req | cookie parse | get sid? | default "")
      let user = (session-user $sid)
      if ($user | is-empty) {
        jerr 401 "Du skal være logget ind for at gemme din score"
      } else {
        "" | .append scores --meta {
          user: $user
          score: ($body.score? | default 0)
          correct: ($body.correct? | default 0)
          total: ($body.total? | default 0)
          attempt: ($body.attempt? | default 1)
          at: (date now | format date "%Y-%m-%dT%H:%M:%SZ")
        }
        {ok: true, user: $user} | jok
      }
    })

    # ---- Leaderboard (bedste score pr. bruger) ----
    (route {path: "/api/leaderboard"} {|req ctx|
      let frames = (.cat -T scores)
      let board = (if ($frames | is-empty) { [] } else {
        $frames | get meta
        | group-by user --to-table
        | each {|g| $g.items | sort-by score | last }
        | sort-by score --reverse
        | first 15
        | select user score correct total at
      })
      $board | jok
    })

    # ---- Live-event fra en spiller (fire-and-forget) ----
    (route {method: "POST" path: "/api/event"} {|req ctx|
      let body = ($in | from json)
      let sid = ($req | cookie parse | get sid? | default "")
      let user = (session-user $sid | default "Gæst")
      "" | .append events --meta ($body | merge {
        user: $user
        at: (date now | format date "%H:%M:%S")
      })
      # Gem deltagerens svage emner ved finish, så admin kan se mønstre
      if ($body.type? == "finish") {
        ($body.missed? | default []) | each {|t|
          "" | .append misses --meta { user: $user, topic: $t, at: (date now | format date "%Y-%m-%dT%H:%M:%SZ") }
        }
      }
      {ok: true} | jok
    })

    # ---- Admin: live SSE-stream af alle events ----
    (route {path: "/api/admin/stream"} {|req ctx|
      let user = (session-user ($req | cookie parse | get sid? | default ""))
      if ($user | is-empty) or ($user not-in (admin-list)) {
        jerr 403 "Kun for admins"
      } else {
        .cat -T events --follow --new
        | each {|f| {data: ($f.meta | to json -r)} }
        | to sse
      }
    })

    # ---- Admin: svageste emner (aggregeret) ----
    (route {path: "/api/admin/misses"} {|req ctx|
      let user = (session-user ($req | cookie parse | get sid? | default ""))
      if ($user | is-empty) or ($user not-in (admin-list)) {
        jerr 403 "Kun for admins"
      } else {
        let frames = (.cat -T misses)
        let board = (if ($frames | is-empty) { [] } else {
          $frames | get meta
          | group-by topic --to-table
          | each {|g| {topic: $g.topic, count: ($g.items | length), players: ($g.items | get user | uniq | length)} }
          | sort-by count --reverse
        })
        $board | jok
      }
    })

    # ---- Admin: effekt af kurset (forbedring fra første til seneste forsøg) ----
    (route {path: "/api/admin/improvement"} {|req ctx|
      let user = (session-user ($req | cookie parse | get sid? | default ""))
      if ($user | is-empty) or ($user not-in (admin-list)) {
        jerr 403 "Kun for admins"
      } else {
        let frames = (.cat -T scores)
        let per = (if ($frames | is-empty) { [] } else {
          $frames | get meta
          | group-by user --to-table
          | where {|g| ($g.items | length) >= 2 }          # kun dem der har taget mere end ét forsøg
          | each {|g|
              let s = ($g.items | sort-by at)
              let first = ($s | first)
              let last = ($s | last)
              {
                user: $g.user
                attempts: ($g.items | length)
                firstCorrect: $first.correct
                lastCorrect: $last.correct
                dCorrect: ($last.correct - $first.correct)
                dScore: ($last.score - $first.score)
              }
            }
          | sort-by dCorrect --reverse
        })
        {
          retriers: ($per | length)
          improved: ($per | where dCorrect > 0 | length)
          avgDeltaCorrect: (if ($per | is-empty) { 0 } else { $per | get dCorrect | math avg })
          avgDeltaScore: (if ($per | is-empty) { 0 } else { $per | get dScore | math avg })
          perUser: ($per | first 12)
        } | jok
      }
    })

    # ---- Admin: dashboard-siden (kun for admins) ----
    (route {path: "/admin"} {|req ctx|
      let user = (session-user ($req | cookie parse | get sid? | default ""))
      if ($user | is-empty) or ($user not-in (admin-list)) {
        "<!doctype html><meta charset=utf-8><body style='font-family:sans-serif;background:#1a1730;color:#eee;text-align:center;padding:60px'><h1>🔒 Kun for admins</h1><p>Log ind som admin-bruger på <a style='color:#a78bfa' href='/'>forsiden</a> først.</p></body>"
        | metadata set { merge {'http.response': {status: 403, headers: {"Content-Type": "text/html; charset=utf-8"}}} }
      } else {
        .static "public" "/admin.html"
      }
    })

    # ---- Statiske filer (fallback index.html) ----
    (route true {|req ctx|
      .static "public" $req.path --fallback "index.html"
    })
  ]
}
