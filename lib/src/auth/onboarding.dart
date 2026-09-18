import 'package:flutter/material.dart';

import '../../onekm_core.dart';

/// One intro page: icon, headline, sub-copy.
class OnboardingPage {
  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// First-run intro (splash → onboarding → login): swipeable pages with
/// dots, Skip, and a Get started CTA on the last page. Host apps pass
/// their own pages; [onDone] persists the seen-flag and routes on.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.pages,
    required this.onDone,
  }) : assert(pages.length > 0);

  final List<OnboardingPage> pages;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  var _index = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == widget.pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: kPaddingPage,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
              const OneKmLogo(height: 40),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: widget.pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final p = widget.pages[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(p.icon, size: 72),
                        const SizedBox(height: 24),
                        Text(
                          p.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.subtitle,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.pages.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: i == _index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: last
                      ? widget.onDone
                      : () => _pager.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
