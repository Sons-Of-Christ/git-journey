# Q&A Prep — ParaBank STLC Presentation

## On the release decision

**Q: Why NO-GO if 82% of tests passed — isn't that a good score?**
A: 82% tells you the *volume* of things working, not the *severity* of what's broken. One of the failures (DEF-005) lets the loan system approve a loan where the down payment exceeds the loan amount — a financial logic failure, not a cosmetic bug. Our Phase 2 exit criteria set a hard rule: zero open Critical defects before release. We're honoring that rule rather than letting a high pass rate talk us out of it.

**Q: What would make you change this to GO?**
A: One specific thing: DEF-005 fixed and retested against the full loan boundary test set (TC-044–TC-050), not just the one failing case — because a fix can accidentally break an adjacent boundary that was previously passing.

**Q: Two of the three Critical defects are already fixed. Why not just release with the third one flagged as "known issue"?**
A: Because this one is different in kind — DEF-007 and DEF-008 were edge-case timing/session issues; DEF-005 is a core safeguard being bypassable, on the record-keeping system for actual loan money. Accepting a "known issue" for that sets a precedent we're not comfortable defending to the client's risk/compliance function.

## On methodology and coverage

**Q: Why only 75% requirements coverage — isn't that low for a release decision?**
A: It's honest, not low performance. Two full modules (Find Transactions, Update Contact Info) were out of scope for test *design* in Phase 3 by the assignment's own module list, not because we ran out of time. We reported that explicitly rather than letting a big test case count imply full coverage.

**Q: How did you decide which 6 modules to focus on?**
A: Risk-based prioritization from Phase 2 — features ranked by financial/security impact if they failed, not by how many fields or how visually complex they were. Login, Transfer Funds, Bill Pay, and Account Overview got the deepest coverage because a defect there costs real money or exposes another customer's data.

**Q: You had no formal requirements document. How did you get requirements at all?**
A: Hands-on exploration of the live application in Phase 1 — treating observed behavior as a *hypothesis* to test, not ground truth, and explicitly flagging anything undocumented (like the loan approval threshold) as an assumption rather than a confirmed rule.

## On defects

**Q: How do you know your severity/priority ratings are correct and not just your opinion?**
A: Each one was justified individually in the Phase 5 Defect Triage Workshop — e.g., DEF-007 is Critical because it's triggerable through ordinary customer behavior (a fast double-click), not a contrived attack, with direct, unrecoverable financial consequence. That's a different bar than "this looks bad to me."

**Q: Why did scripted testing miss things exploratory testing found (session issue, error message enumeration)?**
A: Scripted test cases check whether an action produces the *expected UI outcome* — e.g., "does logout show the login page." They don't check underlying state like whether a session token was actually invalidated. That requires a different technique (post-logout back-navigation + dev tools), which is exactly what exploratory testing is for.

**Q: 4 of 11 defects trace back to Phase 1 gaps. Doesn't that mean Phase 1 failed?**
A: The opposite — it means Phase 1 worked as intended. Flagging those areas as ambiguous *predicted* where real defects would later be found. The failure mode we avoided was guessing at those rules instead of flagging them, which would have hidden the risk instead of surfacing it.

## On process and constraints

**Q: You were the only tester for two weeks. How do you know you found everything?**
A: We don't, and we say so — the Quality Risk Assessment explicitly lists "single-tester resourcing limits" as an accepted, documented risk rather than implying full coverage. The goal was proportionate, risk-weighted coverage within a real constraint, not exhaustive testing.

**Q: If you had another week, what would you do differently?**
A: Two things: get client confirmation on the outstanding requirement gaps (loan threshold, transfer boundaries) earlier so test cases could be fully deterministic instead of "observe and record," and add coverage for the two untested modules before making any release claim about the whole application.

**Q: How did you decide what NOT to test?**
A: Explicitly, in Phase 3's "What Would You NOT Test" exercise — things like exhaustive field-length testing on a low-risk module, or full penetration testing, were deprioritized with a stated reason and a stated residual risk, not silently dropped.

## Curveballs

**Q: If the CEO told you to release today regardless, what would you do?**
A: Document the recommendation and the specific risk (DEF-005) in writing, get an explicit, named sign-off from someone with authority to accept that risk, and make sure the loan-approval exposure is monitored closely post-release — I don't get to unilaterally block a business decision, but I don't let it happen silently either.

**Q: What's the single biggest lesson from this whole engagement?**
A: That a documentation gap isn't a paperwork problem — it's a leading indicator of where real defects live. That connection, from a vague requirement in Phase 1 to a specific reproducible defect in Phase 5, is the thing I'd want a hiring manager to understand I actually learned, not just executed.
