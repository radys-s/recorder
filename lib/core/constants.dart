/// Audio capture format. Locked decision: PCM16 mono 16kHz, one continuous
/// stream per meeting, WAV-wrapped per finished chunk.
const int kSampleRateHz = 16000;
const int kChannels = 1;
const int kBitsPerSample = 16;

/// Chunk splitting targets (RMS/energy-based silence detector, see
/// audio/pcm_chunker.dart). Occasional imperfect/mid-word cuts are accepted
/// in exchange for robustness on long (1h+) recordings.
const Duration kChunkTargetDuration = Duration(seconds: 25);
const Duration kChunkHardCapDuration = Duration(seconds: 30);
const Duration kChunkMinDuration = Duration(seconds: 15);

/// Chunk splitting while live answering is on.
///
/// Groq bills Whisper by audio-seconds, not per request, so cutting the same
/// audio into more pieces costs the same money — only the request rate goes
/// up, which the existing backoff already absorbs. What it buys is latency: an
/// answer cannot arrive before the chunk carrying the question has been cut,
/// and a 25 s chunk means a 25 s wait for a question asked at its start.
///
/// `kConfidentSilenceDuration` deliberately stays where it is, so cuts still
/// land on real pauses between sentences rather than mid-question.
const Duration kFastChunkMinDuration = Duration(seconds: 8);
const Duration kFastChunkTargetDuration = Duration(seconds: 13);
const Duration kFastChunkHardCapDuration = Duration(seconds: 20);

/// Ceiling on the loudness gain for automatic sensitivity: +24 dB, enough for a
/// teacher across a classroom. The gain itself is measured per chunk on the
/// voiced frames and a soft limiter keeps peaks from clipping.
const double kAutoMaxGain = 16;

/// Groq Whisper STT.
const String kGroqTranscriptionUrl =
    'https://api.groq.com/openai/v1/audio/transcriptions';
const String kGroqWhisperModel = 'whisper-large-v3';

/// Groq chat completions, used for meeting notes and (later) live answers.
const String kGroqChatUrl = 'https://api.groq.com/openai/v1/chat/completions';

/// Confirmed on 2026-09-05 against what this account can actually call — Groq's
/// public docs still list `llama-3.3-70b-versatile`, but the key gets a 404 for
/// it, so the docs are not the authority here. Settings → Diagnostika →
/// „Dostupné modely" asks the account itself; if notes or answers start failing
/// with "model does not exist", that is the button to press and this is the
/// line to change.
///
/// Both use the larger model. Answers were on `gpt-oss-20b` at first, on the
/// theory that latency beats quality for something read mid-meeting; in
/// practice the small model gave up on questions the meeting itself answered
/// ("kolik zbývá z rozpočtu" with the budget and the percentage spent both in
/// its context) and fell back on stock phrases. An answer that is wrong or
/// empty is not worth the seconds it saves — the extra latency is a couple of
/// seconds, and [kAnswerTimeout] has room for it.
const String kGroqNotesModel = 'openai/gpt-oss-120b';
const String kGroqAnswerModel = 'openai/gpt-oss-120b';

/// Fixes misheard words in a lesson transcript, once per chunk. The small
/// model has its own rate limit, so this never eats the answers' budget; a
/// 404 moves the corrector to [kGroqAnswerModel].
const String kGroqCorrectionModel = 'openai/gpt-oss-20b';

/// How long a transcript waits for its correction before it is used as heard.
const Duration kCorrectionTimeout = Duration(seconds: 5);

/// An hour of speech is roughly 30-40k characters, which fits in one call.
/// Past this the transcript is summarised in windows and the window summaries
/// merged in a second pass, so a two-hour meeting degrades rather than fails.
const int kNotesWindowThreshold = 48000;
const int kNotesWindowSize = 20000;

/// How much of the meeting so far the answer model is given as context. Enough
/// for the model to answer from what was already said, short enough that the
/// call stays inside [kAnswerTimeout].
const int kAnswerContextChars = 2000;

/// An answer that arrives three minutes into the next topic is worse than no
/// answer, so this call gets a short timeout and no retries at all. Twenty
/// seconds rather than twelve since answers moved to the larger model: the
/// card is anchored to its own segment in the timeline, so arriving a chunk
/// late costs the pinned panel some freshness and nothing else.
const Duration kAnswerTimeout = Duration(seconds: 20);

/// The model's own confidence that the passage really contained a question
/// worth answering. Below this the card is dropped: a wrong card costs the
/// user a glance and a moment of doubt, a missing one costs nothing.
const double kAnswerMinConfidence = 0.5;

/// „Odpověz teď" looks at this much of the end of the lesson.
const Duration kAnswerNowWindow = Duration(seconds: 30);

/// How long „Odpověz teď" waits for the chunk it just cut to be transcribed.
const Duration kAnswerNowMaxWait = Duration(seconds: 12);

/// A second tap within this long answers without cutting another chunk.
const Duration kAnswerNowCutDebounce = Duration(seconds: 5);

/// A question typed into the chat: the student is waiting for it, but it is
/// allowed a bigger context than an automatic answer.
const Duration kChatAnswerTimeout = Duration(seconds: 25);

/// Secure storage key for the user's Groq API key.
const String kGroqApiKeyStorageKey = 'groq_api_key';

/// Silence detection used by the chunker. Frames are the unit of both the RMS
/// measurement and the cut point, so every chunk boundary is frame-aligned
/// (and therefore always sample-aligned).
const Duration kSilenceFrameDuration = Duration(milliseconds: 100);

/// Normalised RMS (0..1) below which a frame counts as silence. ~-40 dBFS.
/// In a noisy room nothing may ever fall below this, which is fine — the hard
/// cap then does the cutting and chunks come out at exactly [kChunkHardCapDuration].
const double kSilenceRmsThreshold = 0.01;

/// How much continuous silence is needed to cut *before* reaching the target
/// length. Past the target a single silent frame is enough.
const Duration kConfidentSilenceDuration = Duration(milliseconds: 600);

/// A relative dip this long between the minimum and the target is the end of
/// a sentence in continuous speech; the gap between two words is shorter.
const Duration kSentencePauseDuration = Duration(milliseconds: 400);

/// Past the target a dip this long is enough.
const Duration kShortPauseDuration = Duration(milliseconds: 200);

/// At the hard cap the chunk is cut at the quietest point of this much audio
/// before it, rather than mid-word.
const Duration kCutLookbackDuration = Duration(seconds: 3);

/// Automatic sensitivity: the first estimate of the room after this much
/// audio, then a fresh one over each window.
const Duration kCalibrationWarmup = Duration(seconds: 3);
const Duration kCalibrationWindow = Duration(seconds: 20);

/// Speech this far above the room's own noise is enough for Whisper.
///
/// Distance is what decides it: a voice loses about 6 dB every time it gets
/// twice as far away, so a teacher across the room arrives barely above the
/// class itself. Below [kWeakSignalSnrDb] for [kWeakSignalPatience] the
/// student is told to move the phone; it takes [kGoodSignalSnrDb] to call it
/// good again, so one quiet minute does not make the warning flicker.
const double kWeakSignalSnrDb = 12;
const double kGoodSignalSnrDb = 15;
const Duration kWeakSignalPatience = Duration(seconds: 60);

/// How often the signal quality is re-measured, over the last
/// [kCalibrationWindow] of audio.
const Duration kSignalQualityInterval = Duration(seconds: 5);

/// How many scored segments a lesson needs before its mean confidence is
/// allowed to call the whole recording badly heard. One mumbled chunk in an
/// otherwise clear lesson is normal; a dozen of them is the room.
const int kWeakAudioMinScoredSegments = 8;

/// Below this length a chunk carries no words, only room tone — and Whisper
/// answers silence with a confident hallucination ("you", "Thank you.") rather
/// than an empty string. Such a chunk is still written to disk and still gets a
/// segment row, so the timeline stays complete; it just never reaches the API.
const Duration kMinTranscribableDuration = Duration(milliseconds: 500);

/// Normalised RMS above which a 100 ms frame could be somebody talking.
/// ~-48 dBFS: well under [kSilenceRmsThreshold], because this one decides
/// whether a chunk is uploaded at all, and a speaker far from the phone must
/// never be mistaken for silence. A quiet room's noise floor sits below it.
const double kVoicedRmsThreshold = 0.004;

/// A chunk with less voiced audio than this is never sent to Whisper.
///
/// The root of the "it wrote something I never said" reports: pinned to Czech,
/// Whisper answers a chunk of room tone with a plausible sentence rather than
/// nothing, and no text filter can tell that sentence from speech. Not
/// uploading it removes the problem instead of chasing its symptoms. Three
/// frames is less than one short word, so any real speech clears it.
const Duration kMinVoicedDuration = Duration(milliseconds: 300);

/// Size of the canonical RIFF/WAVE header prepended to each chunk.
const int kWavHeaderSize = 44;

/// Development-only: WAV files the replay audio source will look for in the
/// app documents directory, in order of preference — the first one present
/// wins, so which test runs is decided by which files were pushed. Czech first,
/// because that is the language real meetings are in.
const List<String> kReplayAudioFileNames = [
  'test_cs_m23.wav',
  'test_cs_web.wav',
  'test_cs.wav',
  'test_cs_silence.wav',
  'test_cs_questions.wav',
  'test_long.wav',
  'test_speech.wav',
];

/// Groq's agentic model: it runs a web search server-side inside an ordinary
/// `/chat/completions` call and answers from what it found.
///
/// Confirmed available to this account on 2026-09-08 via Settings →
/// Diagnostika → „Dostupné modely", alongside `groq/compound`. The `-mini`
/// variant makes a single tool call rather than several, which is both what a
/// one-sentence factual question needs and what keeps the extra hop from
/// doubling the wait for a card. If answers start coming back thin, the larger
/// `groq/compound` is a one-word change here.
///
/// Two known habits of the mini variant are handled in code rather than by
/// switching: it sometimes answers from training data without searching (the
/// hop then returns null, so no card claims a web source — see
/// `WebAnswerService.lookUp`), and it sometimes trips `request_too_large` once
/// fetched pages are folded into its context (re-tossed, see
/// [kWebRetryBudget]).
const String kGroqWebAnswerModel = 'groq/compound-mini';

/// Longer than [kAnswerTimeout] because this call includes a real web round
/// trip. It is off the critical path — transcription never waits on it, and a
/// timeout falls back to the answer the first call already produced — so the
/// only thing a generous budget costs is how long a card can lag its question.
const Duration kWebAnswerTimeout = Duration(seconds: 25);

/// How long [WebAnswerService] keeps re-tossing a call that came back `413`.
///
/// The web model shares an 8 000-token-per-minute ceiling with the pages its
/// own search fetched, so roughly two calls in three are rejected outright —
/// but the rejection arrives in four or five seconds, and which pages the
/// backend opens differs every time, so simply asking again is a real fix
/// rather than a hope. Three tosses inside this budget get the answer through
/// about three times in four, and it leaves room for the ten-second wait a
/// `429` sometimes asks for.
///
/// It is a wall-clock budget rather than an attempt count on purpose: what
/// M15's "no retries" rule actually protects is the user not reading an answer
/// long after the room moved on, and that is a matter of seconds elapsed, not
/// of how many requests were spent. A call that is merely slow therefore gets
/// no second attempt at all — the budget is already gone by the time it fails.
const Duration kWebRetryBudget = Duration(seconds: 18);

/// A hard cap on tosses inside [kWebRetryBudget]. The budget assumes each
/// rejection takes a few seconds to arrive; one that comes back instantly
/// would otherwise be re-sent dozens of times before the clock ran out.
const int kWebMaxAttempts = 4;

/// How many sources a card shows. Three fits one row of chips on a phone, and
/// a wall of links is not what someone glancing at their phone mid-meeting is
/// going to read.
const int kMaxAnswerSources = 3;

/// Optional OpenAI-compatible services behind the AI router (M40). Model ids
/// were checked against the vendors' docs on 2026-09-17; each list is tried in
/// order, so a retired id costs one 404 and moves on.
const String kMistralApiKeyStorageKey = 'mistral_api_key';
const String kCerebrasApiKeyStorageKey = 'cerebras_api_key';
const String kCustomAiKeyStorageKey = 'custom_ai_key';
const String kCustomAiBaseUrlStorageKey = 'custom_ai_base_url';
const String kCustomAiModelStorageKey = 'custom_ai_model';

const String kMistralBaseUrl = 'https://api.mistral.ai/v1';
const String kCerebrasBaseUrl = 'https://api.cerebras.ai/v1';
const String kGroqBaseUrl = 'https://api.groq.com/openai/v1';

const List<String> kMistralFastModels = [
  'mistral-small-latest',
  'ministral-8b-latest',
];
const List<String> kMistralStrongModels = [
  'mistral-medium-latest',
  'mistral-large-latest',
  'mistral-small-latest',
];
const List<String> kMistralVisionModels = [
  'mistral-medium-latest',
  'mistral-small-latest',
  'mistral-large-latest',
];
const List<String> kCerebrasModels = ['gpt-oss-120b', 'qwen-3.8-27b'];

/// Cerebras' free tier caps context at ~65k tokens; bigger requests skip it.
const int kCerebrasMaxInputTokens = 55000;

/// Above this estimated input, Mistral's long context goes first.
const int kRouterLargeInputTokens = 20000;

/// First cooldown after a rate limit or overload, doubled per repeat.
const Duration kRouteCooldown = Duration(seconds: 60);
const Duration kRouteMaxCooldown = Duration(minutes: 10);

/// Secure storage key for the optional Google Gemini API key.
const String kGeminiApiKeyStorageKey = 'gemini_api_key';

const String kGeminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta';

/// Photos, lookups and typed questions. Checked against Google's model list
/// on 2026-09-15: `gemini-3.8-flash` is newer, but the newest model is where
/// free-tier limits are tightest, and „Ověřit klíč" in Settings says whether
/// this id is still offered to the key.
const String kGeminiModel = 'gemini-3.5-flash';

/// Card summaries: a cheap call nobody waits for.
const String kGeminiLiteModel = 'gemini-3.5-flash-lite';

/// Reasoning tokens count against `maxOutputTokens`; none of these calls
/// needs more than a little.
const String kGeminiThinkingLevel = 'LOW';

/// A Gemini chat answer carries far more context than a Groq one.
const Duration kGeminiChatTimeout = Duration(seconds: 40);

/// An automatic answer in a lesson on Gemini. Shorter than a typed question:
/// a late card is worth less, and Groq still gets its turn after a timeout.
const Duration kGeminiLiveAnswerTimeout = Duration(seconds: 25);

/// Výpisky on Gemini: one call over the whole lesson, so a long one.
const Duration kGeminiNotesTimeout = Duration(seconds: 150);

/// Card suggestions after a lesson's notes.
const Duration kCardSuggestionTimeout = Duration(seconds: 60);
const int kCardSuggestionMaxChars = 4000;

/// „Shrnutí předmětu" reads every lesson's výpisky at once. Gemini takes
/// a school year of them whole; the router's models get an even share per
/// lesson, since a smaller context window is the likelier reason Gemini is
/// not the one answering.
const int kSubjectSummaryGeminiChars = 400000;
const int kSubjectSummaryRouterChars = 24000;
const Duration kSubjectSummaryTimeout = Duration(seconds: 150);

/// How much of the student's context, photo text and Q&A výpisky on Groq read,
/// all blocks together — Groq's per-minute token cap is shared with the notes.
const int kNotesExtrasGroqChars = 8000;

/// How much of a card one digest call reads. Groq's share stays well under
/// its 8 000-token minute; Gemini reads practically any card whole.
const int kDigestGroqChars = 6000;
const int kDigestGeminiChars = 60000;

const Duration kCardDigestTimeout = Duration(seconds: 40);

/// The stored card summary is cut to this.
const int kCardSummaryMaxChars = 600;

/// Photos are downscaled on pick: enough for OCR, a fraction of the image
/// tokens and of the disk space a phone camera's original would take.
const double kPhotoMaxDimension = 1600;
const int kPhotoJpegQuality = 85;

/// At most this many page photos go into one OCR call.
const int kMaxPagePhotos = 10;

/// Reading pages or a board is a vision call with a long reply.
const Duration kGeminiPhotoTimeout = Duration(seconds: 90);

/// „Dohledat" searches and writes a whole card.
const Duration kCardLookupTimeout = Duration(seconds: 90);

/// How many source links one card keeps across several look-ups.
const int kMaxCardSources = 8;

/// A chunk shorter than this was cut by the silence detector rather than by a
/// hard cap, so the transcript it produced ends at a real pause in the room.
///
/// Derived rather than stored: the two chunk profiles cap at 20 s (fast) and
/// 30 s (normal), and which one a meeting used is decided when recording
/// starts, not when the answer is considered. Staying below the *lower* cap by
/// the plan's ~1.5 s margin is therefore true in both profiles — it costs some
/// long normal-profile chunks a pause they really did end on, which is the
/// cheap direction to be wrong in.
const Duration kPauseCutMaxChunkDuration = Duration(milliseconds: 18500);

/// The refined transcript after a recording: windows of consecutive chunks.
///
/// Gemini gets 4 minutes rather than 5: a window closes on the first chunk
/// past the target and a short last window is merged into the one before, so
/// a 4-minute target stays under ~5.5 minutes — ~10.5 MB of 16 kHz WAV and
/// ~14 MB once base64-encoded, clear of the 20 MB inline request limit.
const Duration kRefinedGeminiWindow = Duration(minutes: 4);
const Duration kRefinedWhisperWindow = Duration(minutes: 2);

/// A last window shorter than this joins the one before it.
const Duration kRefinedMinLastWindow = Duration(minutes: 1);

/// A window with less speech than this is ready and empty without a request.
const int kRefinedMinVoicedMs = 1000;

/// Frame level counted as speech when a window's chunks are re-levelled —
/// the automatic profile's starting threshold.
const double kRefinedVoicedRms = 0.003;

/// Five minutes of audio in, a few thousand words out.
const Duration kRefinedGeminiTimeout = Duration(seconds: 180);
const Duration kRefinedWhisperTimeout = Duration(seconds: 120);

/// How long a failed window waits before its next try. Long on purpose:
/// the usual failure is a per-minute rate limit, and nobody is waiting.
const List<Duration> kRefinedRetryDelays = [
  Duration(seconds: 30),
  Duration(minutes: 2),
];

/// The previous window's ending, handed to the next as context.
const int kRefinedContextChars = 500;
