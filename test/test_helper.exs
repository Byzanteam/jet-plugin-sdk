{:ok, _apps} = Application.ensure_all_started(:mimic)

Mimic.copy(Joken.Signer)

ExUnit.start(capture_log: true)
