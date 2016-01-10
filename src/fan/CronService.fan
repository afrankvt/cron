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
  new make(|This|? f := null)
  {
    if (f != null) f(this)
  }

  ** Directory for job config and logs.
  const File dir := Env.cur.workDir + `cron/`

  ** Start service.
  override Void onStart() { actor.send(CronMsg("init")) }

  ** Stop service will block until all jobs are complete.
  override Void onStop()
  {
    actor.pool.stop.join
    jobPool.stop.join
  }

//////////////////////////////////////////////////////////////////////////
// Jobs
//////////////////////////////////////////////////////////////////////////

  ** List current jobs.
  CronJob[] jobs()
  {
    actor.send(CronMsg("list")).get(5sec)
  }

  ** Add a CronJob to this service.
  This addJob(Str name, Method method, CronSchedule schedule)
  {
    actor.send(CronMsg("add", CronJob(name, method, schedule))).get(5sec)
    return this
  }

  ** Remove given job from service.
  This removeJob(Str name)
  {
    actor.send(CronMsg("remove", name)).get(5sec)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  private const Actor actor := Actor(ActorPool { name="CronService" })
    |msg| { actorReceive(msg) }

  private const ActorPool jobPool := ActorPool { name="CronService-Jobs" }

  private Obj? actorReceive(CronMsg msg)
  {
    cx := Actor.locals["cx"] as CronCx
    switch (msg.op)
    {
      case "init":   return onInit
      case "list":   return cx.jobs.toImmutable
      case "add":    return onAdd(cx, msg.a)
      case "remove": return onRemove(cx, msg.a)
      case "check":  return onCheck(cx)
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
    if (cx.jobs.contains(job)) throw Err("Job already exists: $job.name")
    cx.jobs.add(job)
    log.info("job added: $job")
    return null
  }

  ** Remove a job.
  private Obj? onRemove(CronCx cx, Str name)
  {
    job := cx.jobs.find |j| { j.name == name }
    if (job != null)
    {
      cx.jobs.remove(job)
      log.info("job removed: $job")
    }
    return null
  }

  ** Check if any jobs need to run.
  private Obj? onCheck(CronCx cx)
  {
    try
    {
      now := DateTime.now
      cx.jobs.each |job|
      {
        if (job.schedule.trigger(now, cx.lastRun[job]))
        {
          cx.lastRun[job] = now
          CronJobActor(jobPool, this, job, now).send(null)
        }
      }
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
  new make(Str op, Obj? a := null, Obj? b := null)
  {
    this.op = op
    this.a  = a
    this.b  = b
  }
  const Str op
  const Obj? a
  const Obj? b
}
