---
title: TTK estimator — external inspiration (reference)
type: reference
related:
  - docs/workorders/WO-007-IJ.md
---

# TTK estimator — external inspiration

Reference material for building **badger-ttk**'s time-to-kill estimator — the pure fight-state engine
(WO-007 child "Pure fight-state engine + estimator"). **Not a dependency and not to be shipped
verbatim** — mine it for *approach and edge-case handling* (sampling cadence, smoothing, how it copes
with heals / phase noise / target swaps), then reimplement in our house style and our design
(health-fraction EWMA · Reactivity↔Stability · execute-correction · confidence gate — see WO-007 /
D-005).

## Source

- **WeakAura (computes time-to-kill):** <https://wago.io/Mp8lGjyeP>
- Provided by the human 2026-07-25 as inspiration for the TTK computation. Respect the author's terms
  on the wago page; use as reference, not a copy.

## How to read the logic when the time comes

WeakAuras export strings are `!WA:2!` + **Base64 → LibDeflate (inflate) → LibSerialize (deserialize)**.
To inspect the custom trigger / TTK Lua: paste the string into a live WeakAuras install and read its
custom functions, **or** decode it off-client with LibDeflate + LibSerialize (both are libraries we
already plan to embed for import/export — see WO-007 v1.1). The interesting parts will be the custom
trigger's DPS/health sampling and its TTK formula; compare against our health-fraction EWMA and borrow
whatever smoothing / clamping / reset-on-target-change it does well.

## Import string

```
!WA:2!nF1YVTXXzClZMAB20eBzdHu70MT0qks2s06HTIJALTfLiTyQEqVKYYUViND3z5owlNz9SZkjku0ciuu4ZcTh6vHcKdTN01ElhY5bcf9pahGEQN8Lw0lQFZolPiPKGtqVuEG7SZ89(1(B6ZT)g970FO19YoXNM9E978QBYBUQRBiw8NUgFtmpKWOx4ac1LXBGeWlPFdIA7X4f4Og4kndWwLN3mF(v2drjAkMoxdeHwiNaomhLrXh6eXJpPQAlEi2MrDc3fJcJfGm9xOwwwWX06cVlygkqCrb5LKPLFh57k)UWZ37cwUekj0R3TNmI4CW2wB6B(KNV12iNjJ4(b3WticcN5o3zluDwwc7olhCF)h)IM4s3zQdSyChmFEMpJ)z91xFP2xVrEN64GRu(Lrio2OqKVVX6Eeb2ke3acdMtKD8StUFyKLjUo4jHP5iBLlfoDoWUePLVFA5LtVVGzNe0U4OVjrYLj7GFNmeNGbmrc0gmUXygvinWgcMXpH47FOfYEdholqBtPsLQuQXZEV3qOcmNI8FQwGFULwCEVw)mxcxbxoNpzNDqChJkmMVGe8fAc0PXlDGRktbrxq5P4BR3TplvOP4c71oYSVkPqIDP0wWAxs90jXQIuGJuhOZ7LyGDznF(vQK3mNdo0oitoi75yWOg9g2dkS1c0Q0fIY5ZqofSeiFmvmGzJiWmtBA7Jcdhqov6CHqisViaBRwCiksakB1aTbTRGtQxhIdxFO9IOjVKMNS43TlWMVFrNW0YlzIGITjZfbjfRaFuti3H3e0Q1IyKVWBFhSvKRRQUJVy(LkvyTLEnKvJjPmCaz7dQo)CLRuTCL5mR0(OsCmCKz5s5xAjtkepdtVppUsqjjZ6CwuGzOn4FPmr(bEOu7fI9DJdwYS9V5F7z9BFRxnQ889buk8jui9SwLLkUsEzQli)wdf8bK6ughN4W5v6mpNZ4H1oaA9SXX7ewlWWHeQCRk4Tfv1nLvdQkGYPK36lyOZMeFCDKDZQU(mg3t(oYVT8ctlVyV9uY3)e7C5tSZsw5wTsLvxwEv51KFCFYpq(9KFsA5nMw(HjndYBNo4MNTTeWX2evHDk5WYrmT1f)l(WV6Qx9Jo6O)ZIp8VEJB8OZDU)CQGlBhfkynuYyTahKalFO8h(57UfuCUohfS76jlKx5Gx8YLkn)ZDxLVmFFiHHDwN4i8(TVRCmzw(laXqCBMBP8fQCqOhYHT1XJbKFFOJvE9RpG8shczDvpPkRsDout5Z1noF45KdL6Go8QmdstO4zAksjVv6GBCk(nnzHm9RHQBMAyPDS5LBo41tLLGKfMQiMtqMZoA2G5uf6WX1Kt8u50Qwi59I))UX)pzCtvuiUkMAdEfmzPwWTpBX50ekYj2vfECCOhZ3PP8(V3qYpnTCMVCppgeh9jIMC9kSCwO1MxhlETsdiHacEilFWyMtMt(JsVRABvhzTytOn)1Kpm4ARb7BmVhsnqfZjWr2HqX2SY5LliFCAzEzHGROg2UjUIUFFzMd(VCUCUmQi4Yf4KDmEseYrnFZOsf5I5eQ0cXj3kqF6UkQutG)OxnI88)Z(Kllxr3YjxTMSunzviJ()wJGSCN9aXvqYFPLhMu3tS4JU7rh9Bo6OFLU8cfxRlxtnKpL8PX1XY1Lpt(tHs0FM8Nl)fX1IMBPklw8r38O)nW7)cQRFYgln1iFwHDkweR6YgkLSwMbTLCZvIAGPqf3(h3JS9f)JUr04Von8iPnGFJnMbmatnbXq4HnwhJ2yoykPHlN1WWctO1nc4mBCOAooXnMiMEsKbi(idsi8oMglm48wcimBXWKjwRchp8ikoPgCSiItnYmXuZm1NaFS7UtMD8bZyGPoXcOLjves8eKVbm10oYhPN0RoZNbBz4fpV2ywdvbIE49Wz0LzzgPd6AG2EXts6YOTpvQ1sTeggPcrJzngorn35y5mIXTmMy8X7Gjvlbq7JXc13TtcQTCJ59W2B0kQP14hh2Y69qHg2EiADStRGN67tqx4MzHUQeQ(1Z2IEv8lMq1VtHY2eQ0Cz0MyDUY3jz)282EHkq3PTPYLiHHRcHJMNrHegm3QnhGn2sBZ2r0TltRlZtt94JE8oQawNV3OLMoENKykL43LqBv7Kj2YxH167Dgum2jjiQ(1Qy6e(QUOcA4J9zxcpu0YD2e5hHd70pPmXjCJV5oA7SYOXvkNoVNDi4m59TeluoarvRDSJ2aashXXqpR4TgPMpPTthOAW2ungaQO4O6G4auQjrne1PBtRxxs1fDI9UDc7QMjam7PWCI3pCp7C7yL1lBNTHlsqsRwtHPFg65ChxeRAbDW2C1DmC6m5FcB(bZ(1Oyamatv7sSc1vu9OmcnrzgO6WfH()OEg)WUlW0t3G6fWmHSFLoRhHeWW9uMpwpMYiWuZtM5h7eo5iDP0EJMlKySQ4zBtrNwjuJLxEMYLn0Gt6ItiM3TH)JN1y6tjF1raslLHZm(4ZmiCBohWuhm7eUdoyMr7wwJ29NjgjEyRhBlJKRUg3tK4UbAAGMMUuRkwFct8bFDTWbDElwie5NE8E3BW49odtVbHgjWHZ8nWfONCCBxFd)mR70tw9u5Xo)aiWCR7hm0UoSQHk41EMXp4gAamQ7nay1pv0W2TbqlN4l33Ha3wdgeiA2gTR7UU(4TjkKN7l2cCPMUaQXAw611aSGCrZgiATjfyAnZae8AnUR(M8Trl)uRfxtD72AwLmlMVCLAMlyUwXfQXxFotZIRAwJxAULMBHIRutdRohGCn(2R8DyumCl0ZNaa3RwooZp(O9u4EPWOjU3EbBgKCryfr2sh59)ba06baiV(Yz(7QhbdKKt0zOQa4laElJF9(FqmKAAnEenEqxo1vjai2bxrPHU4Ylgf9dLpsbHwHM(WUo(69poaV(yf)pKVqUr8YgAy62TWK7Tx7LtsdSL)E5FqYQbgrmzX39wb1gqZldAHCFV2B3xS6FzkarU58WeNnKlkfWDdLBoLcm8)9
```
