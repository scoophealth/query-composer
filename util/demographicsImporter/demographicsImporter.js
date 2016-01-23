// Retrieve
var MongoClient = require('mongodb').MongoClient;
var util = require('util');

var preconditions = true;

if(process.env.QUERY_TITLE === null || process.env.QUERY_TITLE === undefined)
{
         console.log('ERROR: QUERY_TITLE environment variable not set.');
}
else
{
	console.log('QUERY_TITLE: ' + process.env.QUERY_TITLE);
}


if(process.env.RETRO_QUERY_TITLE === null || process.env.RETRO_QUERY_TITLE === undefined)
{
         console.log('ERROR: RETRO_QUERY_TITLE environment variable not set.');
}
else
{
	console.log('RETRO_QUERY_TITLE: ' + process.env.RETRO_QUERY_TITLE);
}
// Connect to the db
MongoClient.connect('mongodb://hubdb:27017/query_composer_development', function(err, db) {
  if(err) { return console.dir(err); }

  db.collection('queries', null,
    function(err, queriesCollection)
    {
      if(err) { throw err; }

      //fetch the retro query excution
      //****************************************************************************
      queriesCollection.find({title:process.env.RETRO_QUERY_TITLE}).toArray(
        function(err, retroQueries)
        {
          if(err) { throw err; }

          if(retroQueries.length != 1)
          {
            throw new Error('Not one and only one retro query: ' + process.env.RETRO_QUERY_TITLE);
          }

          var retroQuery = retroQueries[0];

          if(retroQuery.executions.length != 1)
          {
            throw new Error('Not one and only one execution for retro query: ' + process.env.RETRO_QUERY_TITLE);
          }

          retroQuery.executions = retroQuery.executions.sort(
            function(a,b)
            {
              return a.time > b.time ? 1 : b.time > a.time ? -1 : 0;
            }
          );

          var retroQueryExecution = retroQuery.executions[0];

          //****************************************************************************

          //fetch query executions
          //****************************************************************************
          var queries = queriesCollection.find({title:process.env.QUERY_TITLE}).toArray(
            function(err, queries)
            {
              if(err) { throw err; }

              if(queries.length != 1)
              {
                throw new Error('Not one and only one query: ' + process.env.QUERY_TITLE);
              }

              var query = queries[0];

              var queryExecutions = query.executions;
              //****************************************************************************

              //fetch retro retroResults
              //****************************************************************************
              var retroResults = retroQueryExecution.aggregate_result;
              //****************************************************************************

              //build simulated executions
              //****************************************************************************
              var simulatedExecutions = {};

              for( var key in retroResults)
              {
                if( !retroResults.hasOwnProperty(key))
                {
                  continue;
                }

                var execution = JSON.parse(key);

                var date = execution.date/1000;//leave in milliseconds
                var simulatedExecution;

                if(!execution.gender || !execution.ageRange || !execution.pid || !execution.date)
		{
			throw new Error('Error: Missing field');
		}

		var ar_key = execution.gender + '_' +
                             execution.ageRange + '_' +
                             execution.pid;

		if(!simulatedExecutions[date])
		{
			var aggregate_result = {};
			aggregate_result[ar_key] = retroResults[key];
			simulatedExecution = {'_id':retroQueryExecution._id,
                                      'aggregate_result':aggregate_result,
                                      'notification':null,
                                      'time':date,
                                      'simulated':true
                                     };
			simulatedExecutions[date] = simulatedExecution;
		}
		else
		{
			simulatedExecution = simulatedExecutions[date];
			simulatedExecution.aggregate_result[ar_key] = retroResults[key];
		}
              }
              //****************************************************************************

              //add the simulated executions to the execution List
              //****************************************************************************
              for( var se in simulatedExecutions)
              {
                if( !simulatedExecutions.hasOwnProperty(se))
                {
                  continue;
                }

                queryExecutions.push( simulatedExecutions[se] );
              }
              //****************************************************************************

              //update the query with the retro results
              //****************************************************************************

              queriesCollection.updateOne({title:process.env.QUERY_TITLE}, {$set:{executions:queryExecutions}}, {upsert:true},
                  function(err, result)
                  {
                    if(err)
                    {
                      throw new Error(err);
                    }

		    db.close(
			function(err, result)
			{
				if(err)
				{
					console.log('ERROR: closing db - ' + error);
				}
				else
				{
					console.log('SUCCESS');
				}
			});
                  });

              //****************************************************************************
            });

        });
    }
  );
});
