# Voice Talent Outreach Playbook

Target outcome: one signed individual VTuber, 50K–200K subscribers, perpetual non-exclusive voice pack license for OkiMission's first paid voice character, total budget under ¥700K including lawyer + studio.

This document is the human-action checklist for Phase B-1 of the GTM plan. The code in `OkiMissionVoicePack` and `OkiMissionPlatformKit/Voice` is talent-agnostic; this is what unblocks revenue.

---

## 1. Shortlist Criteria

A candidate is in scope when all of the following hold:

- Independent / 個人勢 (not under Cover Corp., ANYCOLOR, Noripro, 774inc — those routes require agency negotiation and 6+ figure budgets)
- 50,000–200,000 YouTube subscribers (sweet spot for cost vs. audience reach)
- Active in the last 30 days (proves they will record on schedule)
- Has at least one prior commercial collaboration (proves they can sign and deliver a contract — Skeb / ココナラ / past app or game voice)
- Audience demographic skews 18–28 (matches our morning-alarm target)
- Voice character compatible with morning wakeup tone (no purely growling / horror / heavy gimmick voices)

Disqualifiers:

- Public talent disputes or recent account migrations (signals legal / management instability)
- Hard exclusivity on competitor alarm / morning routine apps
- No business inquiry channel listed (gmail / Twitter DM / business form must exist)

## 2. Initial Shortlist (research note)

Do not hard-code names here. Search workflow:

1. YouTube → "個人勢 VTuber 朝活" / "個人勢 VTuber ASMR 短尺" / "個人勢 VTuber ボイスドラマ"
2. Filter by subscriber count (50K–200K) and last-upload date (≤ 30 days)
3. Check description block / channel banner for 「お仕事のご依頼」business inquiry contact
4. Cross-check Skeb / Coconala / Booth for proven commercial work
5. Build a 10-name shortlist in a private sheet (do not commit the list to this repo)

## 3. Outreach Email Template (Japanese)

```
件名: 【ご相談】iOSアラームアプリ「OkiMission」音声ご出演のお願い

[タレント名] 様
[マネージャー様 / ご担当者様]

突然のご連絡失礼いたします。
iOSアラームアプリ「OkiMission」を開発しております、syou6 と申します。

このたび、本アプリのキャラクターボイスとして
[タレント名] 様にご出演いただきたく、ご相談のご連絡を差し上げました。

■ アプリ概要
- iOS 26+ 対応のミッション型アラームアプリ
- 起床ミッション（計算、腕立て、ものさがし等）をクリアするまで
  アラームが止まらない仕様
- 起床時、ミッション中の応援、クリア時に
  キャラクターボイスが再生される設計

■ ご依頼内容
- 録音ボイス約50ライン
  （アラーム音 3本 / ミッション中の声がけ 30本 / クリア時 17本）
- スタジオ収録（東京都内、半日想定）
- アプリ内での再生のみ（音源ダウンロード不可、SNS転載不可）

■ ご提示条件
- 出演料: ご相談の上決定（参考: ¥XXX,XXX を想定）
- 使用期間: 契約締結日より2年（更新オプションあり）
- 利用範囲: 「OkiMission」iOSアプリ内再生のみ
- AI学習・音声合成への利用: 禁止
- サブライセンス: 禁止
- ご本人または事務所からの書面要求により30日以内の削除に応じます

ご検討いただける場合は、契約条件詳細、収録スケジュール、
お支払い方法についてご相談させていただけますと幸いです。

何卒よろしくお願いいたします。

syou6
[メールアドレス]
[ウェブサイト / GitHub URL]
```

Tips:

- Send from a domain email, not gmail (signals professional)
- Include a 1-page PDF with screenshots / app concept attached
- Wait 7 business days before follow-up; do not chase on social media
- If they ask for a contract template before quoting, send Section 4 below

## 4. Contract Non-Negotiables

Derived from `/Users/sho/wayk/research/03_voice_license.md` and `/Users/sho/wayk/research/04_jp_legal.md`. Every contract MUST include:

| Clause | Required Text (summary) |
|---|---|
| AI合成禁止 | "本契約に基づく音源を機械学習・音声クローニング等のAI生成技術の学習・推論用途に使用しない" |
| サブライセンス禁止 | "甲は本音源を第三者へ再ライセンス・再配布しない" |
| 期間限定 | "契約締結日から2年。書面合意により更新可能" |
| 30日削除権 | "乙の書面要求から30日以内に、甲は本音源を本アプリから削除する" |
| 利用範囲明記 | "「OkiMission」iOSアプリ (App Store ID: 未定) 内での再生に限る。ダウンロード提供、SNS転載は不可" |
| 出演料支払時期 | "収録完了から30日以内に銀行振込" |
| 解除事由 | 乙の死亡、長期活動休止、または本アプリの提供終了 |
| 紛争解決 | 東京地方裁判所を第一審の専属合意管轄裁判所とする |

Optional but recommended:

- "将来的にAI音声合成を利用する場合は、別途書面合意により追加報酬を支払う" — preserves Pattern C optionality without committing now
- "本契約に関連して乙が肖像権・パブリシティ権侵害を主張された場合、甲は誠実に協議に応じる" — limits甲's exposure to talent disputes

弁護士費用見積もり: 規約+PP+特商法+ライセンス契約のセットで¥200,000–¥500,000 (STORIA等)。

## 5. Recording Session Checklist

| Step | Owner | Notes |
|---|---|---|
| スタジオ予約 (青葉台スタジオ / サウンドイン / PAS) | syou6 | 半日¥40,000–¥90,000 |
| 台本 50ライン仕上げ + 校正 | syou6 | 文字数・読み所要時間込で確認 |
| 収録監督 (ディレクター) | syou6 or 外注 | 監督なしならsyou6が現場入り |
| 仮録り (5ライン) + タレント承認 | スタジオ | 本録り前にトーン合わせ |
| 本録り (45 ライン残り) | スタジオ | 想定2-3時間 |
| 音源編集 (ノイズ除去・音量正規化・ファイル分割) | エンジニア | ¥30K-¥80K、納期1週間 |
| ファイル受領 (.m4a 推奨、48kHz/24bit) | syou6 | アプリBundleに配置 |
| タレントによる最終確認 | タレント | 契約上の承認ステップ |
| 公開許諾書面取得 | syou6 + 弁護士 | App Store提出前必須 |

## 6. Budget Worksheet

| 項目 | 想定額 |
|---|---|
| 出演料 (50K-200K subs帯) | ¥100,000-¥300,000 |
| スタジオ + エンジニア (半日) | ¥50,000-¥120,000 |
| 音源編集 | ¥30,000-¥80,000 |
| ディレクター外注 | ¥0-¥50,000 |
| 弁護士 (契約レビュー単発) | ¥50,000-¥150,000 |
| 雑費 (交通・資料・台本印刷) | ¥10,000-¥30,000 |
| **合計レンジ** | **¥240,000-¥730,000** |

## 7. Decision Gates

Gate A — 契約締結まで: 候補1名から書面合意取得ができなければPhase B-1中止、Phase Aのまま運用継続。

Gate B — 収録から30日経過: 編集音源を本番ビルドに統合できなければ¥0で撤退判断 (出演料は支払い済み、損切り)。

Gate C — launch後60日: voice pack IAPアタッチ率が12%未満なら次タレント追加せず、現1名を継続運用しながらPattern Aの機能磨きに戻す。12%以上なら2人目契約に進む。

## 8. Outputs to Track

- [ ] 候補10名のショートリスト (private)
- [ ] 初回オファー送信ログ (送信日 / 返信日 / 結果)
- [ ] 契約締結タレント名 + 契約PDFアーカイブ
- [ ] 収録音源50ファイル (Voices/<characterId>/ 配下にバンドル)
- [ ] App Store提出時の音声ライセンス書面
- [ ] アタッチ率測定ダッシュボード (PostHog event: voice_pack_purchased / voice_clip_played)
