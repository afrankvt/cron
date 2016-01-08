//
// Copyright (c) 2014, Andy Frank
// Licensed under the MIT License
//
// History:
//   10 Sep 2014  Andy Frank  Creation
//

using concurrent

**
** CronService
**
const class CronService : Service
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor.
  new make()
  {
    actor.send(CronMsg("init"))
  }

  ** Directory for job config and logs.
  const File dir := Env.cur.workDir + `cron/`

//////////////////////////////////////////////////////////////////////////
// Jobs
//////////////////////////////////////////////////////////////////////////

  ** List current jobs.
  CronJob[] jobs()
  {
    actor.send(CronMsg("list")).get(5sec)
  }

  ** Add a CronJob to this CronService.
  This addJob(CronJob job)
  {
    actor.send(CronMsg("add", job)).get(5sec)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  private const Actor actor := Actor(ActorPool { name="CronService" })
    |msg| { actorReceive(msg) }

  private Obj? actorReceive(CronMsg msg)
  {
    cx := Actor.locals["cx"] as CronCx
    switch (msg.op)
    {
      case "init":  return onInit
      case "list":  return cx.jobs.toImmutable
      case "add":   return onAdd(cx, msg.job)
      case "check": return onCheck(cx)
      default: throw ArgErr("Unknown op: $msg.op")
    }
  }

  ** Init service.
  private Obj? onInit()
  {
    Actor.locals["cx"] = CronCx()
    actor.sendLater(checkFreq, checkMsg)
    log.info("CronService started")
    return null
  }

  ** Add a new job.
  private Obj? onAdd(CronCx cx, CronJob job)
  {
    echo("TODO: add $job")
    return null
  }

  ** Check if any jobs need to run.
  private Obj? onCheck(CronCx cx)
  {
    try
    {
      x := 5 //echo("TODO: check")
    }
    catch (Err err) { log.err("Check failed", err) }
    finally { actor.sendLater(checkFreq, checkMsg) }
    return null
  }

  private const Log log := Log.get("cron")

  private const Duration checkFreq := 1sec
  private const CronMsg checkMsg := CronMsg("check")
}

**************************************************************************
** CronMsg
**************************************************************************

internal const class CronMsg
{
  new make(Str op, CronJob? job := null)
  {
    this.op  = op
    this.job = job
  }
  const Str op
  const CronJob? job
}
